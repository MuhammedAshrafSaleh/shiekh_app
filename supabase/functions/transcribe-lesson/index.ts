// supabase/functions/transcribe-lesson/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Static config ────────────────────────────────────────────────────────────
// Fallback order per validated testing: gemini-flash-latest is LEAST reliable
// (most 503s) despite the name, so it is tried last.
const MODEL_FALLBACK = ["gemini-3.6-flash", "gemini-3.8-flash", "gemini-flash-latest"];
const RETRY_BACKOFF_MS = [10_000, 20_000, 30_000]; // per-model, on HTTP 503 only
const OVERALL_DEADLINE_MS = 100_000; // wall-clock cap (~50s margin under the 150s platform limit)
const MAX_OUTPUT_TOKENS = 65536;
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const GEMINI_FILES_BASE = "https://generativelanguage.googleapis.com/v1beta/files";
const GEMINI_UPLOAD_BASE = "https://generativelanguage.googleapis.com/upload/v1beta/files";
const FILE_ACTIVE_POLL_MS = 2_000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Models default to summarizing long content even when told "transcribe
// everything" — the prompt must explicitly forbid it.
const PROMPT =
  "فرّغ هذا الدرس تفريغًا حرفيًا كاملًا من أول ثانية إلى آخر ثانية. " +
  "اكتب كل كلمة نطق بها الشيخ. لا تلخّص، ولا تختصر، ولا تكتب عناوين أو نقاط — " +
  "النص الكامل فقط، مع ذكر الطابع الزمني عند بداية كل فكرة رئيسية.";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Strip ?key=… / &key=… from any string so a Deno network-error message that
// embeds the request URL can never carry the Gemini API key to the caller or
// persist it in generation_jobs.error_message.
function sanitize(msg: string): string {
  return msg.replace(/[?&]key=[^&\s"']*/g, "");
}

// Extract a Drive FILE_ID from whatever share-link shape the admin pasted:
//   /d/<id>/... | ?id=<id> | uc?export=download&id=<id>
function driveFileId(url: string): string | null {
  const patterns = [/\/d\/([^/?#]+)/, /[?&]id=([^&#]+)/];
  for (const p of patterns) {
    const m = url.match(p);
    if (m) return m[1];
  }
  return null;
}

// Download the Drive audio bytes and upload them to Gemini's resumable Files
// API. Returns { fileUri, mimeType } once the file reaches ACTIVE state.
async function uploadDriveAudioToGemini(
  apiKey: string,
  sourceUrl: string,
  displayName: string,
  deadlineAt: number,
): Promise<{ fileUri: string; mimeType: string }> {
  const fileId = driveFileId(sourceUrl);
  if (!fileId) throw new Error("تعذّر استخراج معرّف ملف Drive من الرابط");
  const downloadUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;

  const dl = await fetch(downloadUrl);
  if (!dl.ok) throw new Error(`فشل تنزيل ملف الصوت من Drive (${dl.status})`);
  const bytes = new Uint8Array(await dl.arrayBuffer());
  if (bytes.byteLength === 0) throw new Error("ملف الصوت المُنزَّل فارغ");
  const mimeType = dl.headers.get("Content-Type")?.split(";")[0].trim() || "audio/mp4";

  // Step 1 — start a resumable upload session.
  let startRes: Response;
  try {
    startRes = await fetch(`${GEMINI_UPLOAD_BASE}?key=${apiKey}`, {
      method: "POST",
      headers: {
        "X-Goog-Upload-Protocol": "resumable",
        "X-Goog-Upload-Command": "start",
        "X-Goog-Upload-Header-Content-Length": String(bytes.byteLength),
        "X-Goog-Upload-Header-Content-Type": mimeType,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ file: { display_name: displayName } }),
    });
  } catch (_e) {
    throw new Error("انقطع الاتصال بخدمة رفع الملفات إلى Gemini");
  }
  if (!startRes.ok) {
    throw new Error(`فشل بدء رفع الملف إلى Gemini (${startRes.status})`);
  }
  const uploadUrl = startRes.headers.get("X-Goog-Upload-URL");
  if (!uploadUrl) throw new Error("لم يُرجِع Gemini رابط الرفع");

  // Step 2 — upload the bytes and finalize in one request.
  const upRes = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      "Content-Length": String(bytes.byteLength),
      "X-Goog-Upload-Offset": "0",
      "X-Goog-Upload-Command": "upload, finalize",
    },
    body: bytes,
  });
  if (!upRes.ok) throw new Error(`فشل رفع ملف الصوت إلى Gemini (${upRes.status})`);
  const upData = await upRes.json();
  let file = upData?.file;
  if (!file?.uri || !file?.name) throw new Error("استجابة رفع الملف غير صالحة");

  // Step 3 — audio is PROCESSING right after upload; poll until ACTIVE.
  while (file.state && file.state !== "ACTIVE") {
    if (file.state === "FAILED") throw new Error("فشلت معالجة ملف الصوت في Gemini");
    if (Date.now() + FILE_ACTIVE_POLL_MS > deadlineAt) throw new Error("deadline_exceeded");
    await sleep(FILE_ACTIVE_POLL_MS);
    let pollRes: Response;
    try {
      pollRes = await fetch(`${GEMINI_FILES_BASE}/${file.name.replace(/^files\//, "")}?key=${apiKey}`);
    } catch (_e) {
      throw new Error("انقطع الاتصال بخدمة Gemini أثناء انتظار المعالجة");
    }
    if (!pollRes.ok) throw new Error(`فشل الاستعلام عن حالة الملف (${pollRes.status})`);
    file = await pollRes.json();
  }

  return { fileUri: file.uri, mimeType };
}

// Call Gemini transcription with model fallback + 503 retry/backoff, honoring
// the deadline. `filePart` is the file_data content part (YouTube uri or the
// uploaded Drive file). Returns the concatenated transcript text.
async function transcribeWithFallback(
  apiKey: string,
  filePart: Record<string, unknown>,
  deadlineAt: number,
): Promise<string> {
  const body = {
    contents: [{ role: "user", parts: [filePart, { text: PROMPT }] }],
    generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS },
  };

  let lastError = "لم يتم إنتاج نص التفريغ";
  for (const model of MODEL_FALLBACK) {
    for (let attempt = 0; attempt < RETRY_BACKOFF_MS.length; attempt++) {
      if (Date.now() > deadlineAt) throw new Error("deadline_exceeded");
      let res: Response;
      try {
        res = await fetch(`${GEMINI_BASE}/${model}:generateContent?key=${apiKey}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
      } catch (_e) {
        lastError = "انقطع الاتصال بخدمة التفريغ";
        break; // network error → next model immediately
      }

      if (res.status === 503) {
        const wait = RETRY_BACKOFF_MS[attempt];
        lastError = "خدمة التفريغ مشغولة مؤقتًا (503)";
        if (attempt === RETRY_BACKOFF_MS.length - 1) break; // retries exhausted → next model
        if (Date.now() + wait > deadlineAt) throw new Error("deadline_exceeded");
        await sleep(wait);
        continue;
      }

      if (!res.ok) {
        lastError = `خطأ من خدمة التفريغ (${res.status})`;
        break; // non-503 error → next model immediately
      }

      const data = await res.json();
      const parts = data?.candidates?.[0]?.content?.parts;
      // Long transcripts can span multiple parts — concatenate them all.
      const text = Array.isArray(parts)
        ? parts.map((p: any) => p?.text ?? "").join("").trim()
        : "";
      if (text) return text;
      lastError = "أعاد النموذج نصًا فارغًا";
    }
  }
  throw new Error(lastError);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ── Auth: verify the caller is an admin via their JWT ──────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);

  const { data: profile, error: profErr } = await callerClient
    .from("users")
    .select("role")
    .eq("id", userData.user.id)
    .single();
  if (profErr || profile?.role !== "admin") return json({ error: "Forbidden" }, 403);

  // ── Validate input ─────────────────────────────────────────────────────────
  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const { lesson_id, source_type, source_url } = payload ?? {};

  if (!lesson_id || typeof lesson_id !== "string") return json({ error: "lesson_id is required" }, 400);
  if (source_type !== "youtube" && source_type !== "drive_audio")
    return json({ error: "source_type must be 'youtube' or 'drive_audio'" }, 400);
  if (!source_url || typeof source_url !== "string" || !source_url.trim())
    return json({ error: "source_url is required" }, 400);

  // ── Service-role client for all writes ─────────────────────────────────────
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // ── Gemini key: read from app_secrets (admin-managed). No env fallback. ─────
  const { data: secret } = await admin
    .from("app_secrets")
    .select("value")
    .eq("key", "gemini_api_key")
    .maybeSingle();
  const GEMINI_API_KEY = secret?.value as string | undefined;
  if (!GEMINI_API_KEY) return json({ error: "AI_KEY_MISSING" }, 400);

  // Mark the lesson as running before starting the long work.
  await admin
    .from("lessons")
    .update({ transcript_status: "running", transcript_error: null })
    .eq("id", lesson_id);

  const { data: job, error: jobErr } = await admin
    .from("generation_jobs")
    .insert({
      lesson_id,
      job_type: "transcribe",
      status: "running",
      created_by: userData.user.id,
    })
    .select("id")
    .single();
  if (jobErr || !job) return json({ error: "Failed to create job", detail: jobErr?.message }, 500);

  const jobId = job.id as string;

  try {
    const deadlineAt = Date.now() + OVERALL_DEADLINE_MS;

    // Build the Gemini file_data content part.
    let filePart: Record<string, unknown>;
    if (source_type === "youtube") {
      // YouTube links are passed directly and need no mime type.
      filePart = { file_data: { file_uri: source_url.trim() } };
    } else {
      const { fileUri, mimeType } = await uploadDriveAudioToGemini(
        GEMINI_API_KEY,
        source_url.trim(),
        lesson_id,
        deadlineAt,
      );
      filePart = { file_data: { file_uri: fileUri, mime_type: mimeType } };
    }

    const transcript = await transcribeWithFallback(GEMINI_API_KEY, filePart, deadlineAt);

    await admin
      .from("lessons")
      .update({
        transcript,
        transcript_status: "ready",
        transcript_error: null,
        transcript_generated_at: new Date().toISOString(),
      })
      .eq("id", lesson_id);

    await admin.from("generation_jobs").update({ status: "done" }).eq("id", jobId);

    return json({ job_id: jobId, transcript_text: transcript });
  } catch (err) {
    const message = sanitize(err instanceof Error ? err.message : String(err));
    await admin
      .from("lessons")
      .update({ transcript_status: "failed", transcript_error: message })
      .eq("id", lesson_id);
    await admin
      .from("generation_jobs")
      .update({ status: "failed", error_message: message })
      .eq("id", jobId);
    return json({ job_id: jobId, error: message }, 500);
  }
});
