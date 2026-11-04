// supabase/functions/generation-worker/index.ts
//
// Background worker for BOTH AI jobs: lesson transcription and question
// generation. Invoked by pg_cron every 2 minutes. Handles AT MOST ONE job per
// invocation, makes exactly ONE Gemini attempt, and re-queues with backoff on a
// transient failure.
//
// Why this exists, and why the numbers below are what they are: docs/AI_QUEUE.md
//
// Auth: not user-facing. verify_jwt is off; the caller must present
// x-worker-secret matching app_secrets.worker_secret.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL_FALLBACK = ["gemini-3.6-flash", "gemini-3.8-flash", "gemini-flash-latest"];

// Retry budget: 24 attempts spanning ~19 hours.
//
// Measured overnight 2026-11-03/04 on the Gemini free tier: 24 CONSECUTIVE
// 503 "experiencing high demand" responses over 7 hours, across all three
// models, including 00:00, 01:00, 02:00 and 04:00 local. There is no quiet
// hour. But capacity does return — a 44-minute mp3 succeeded on attempt 4
// earlier the same day. So the budget must outlast a bad night rather than a
// bad afternoon: it now covers a full day/night cycle.
//
// DO NOT shorten this without new measurements. An earlier draft used 5
// attempts over ~1 hour; against the numbers above it would never succeed.
const MAX_ATTEMPTS = 24;
// Minutes before attempt N+1, indexed by (attempts - 1); past the end, 60.
const BACKOFF_MIN = [2, 5, 10, 20, 30];

const ATTEMPT_DEADLINE_MS = 130_000; // platform wall clock ~150s
const MAX_OUTPUT_TOKENS = 65536;
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const GEMINI_FILES_BASE = "https://generativelanguage.googleapis.com/v1beta/files";
const GEMINI_UPLOAD_BASE = "https://generativelanguage.googleapis.com/upload/v1beta/files";
const FILE_ACTIVE_POLL_MS = 2_000;

const TERMINAL_MESSAGE =
  "تعذّر إتمام العملية بعد عدة محاولات على مدار يوم — خدمة الذكاء الاصطناعي مزدحمة. جرّب مرة أخرى.";

const TRANSCRIBE_PROMPT =
  "فرّغ هذا الدرس تفريغًا حرفيًا كاملًا من أول ثانية إلى آخر ثانية. " +
  "اكتب كل كلمة نطق بها الشيخ. لا تلخّص، ولا تختصر، ولا تكتب عناوين أو نقاط — " +
  "النص الكامل فقط، مع ذكر الطابع الزمني عند بداية كل فكرة رئيسية.";

const SYSTEM_INSTRUCTION = `أنت مساعد متخصص في إعداد أسئلة اختبارية لمحتوى شرعي تعليمي.

## القاعدة الأولى - لا تتجاوزها أبدًا
تولّد الأسئلة من "النص المصدر" المرفق فقط، ولا شيء غيره.
* ممنوع منعًا باتًا إضافة أي حكم فقهي أو معلومة أو رأي غير مذكور صراحة في النص.
* ممنوع الاستعانة بمعرفتك الخارجية حتى لو كنت متأكدًا من صحتها.
* الآيات والأحاديث والنصوص المنقولة: تُنقل حرفيًا كما وردت في المصدر فقط.
* إن كانت المعلومة واردة في النص لكن بشكل غامض، تجاهلها ولا تبنِ عليها سؤالًا.
* النص المرفق هو جزء واحد من محاضرة أطول، فقد يبدأ أو ينتهي في منتصف فكرة.
  تعامل مع هذا بشكل طبيعي ولا تُشر إلى أن النص جزء مقتطع.

## قاعدة العدد
اجتهد في الوصول إلى العدد المطلوب من الأسئلة. النص عادةً يحتمل هذا العدد، فابحث في كامل النص عن كل معلومة تصلح لسؤال قبل أن تتوقف. لكن إن لم يحتمل النص العدد المطلوب فعلًا، أنتج عددًا أقل ولا تخترع معلومة غير موجودة في النص.

## تغطية النص
وزّع الأسئلة على كامل النص من بدايته إلى نهايته بالتساوي. لا تركّز على جزء واحد أو على بداية النص.

## مستويات الصعوبة
* سهل: استرجاع مباشر (تعريف، عدد، اسم، حكم مذكور نصًا)
* متوسط: فهم وربط (علّة الحكم، الفرق بين مفهومين، شرط)
* صعب: تطبيق واستنباط (حالة عملية تطبق القاعدة المذكورة)

## صياغة السؤال
* أربعة خيارات، إجابة واحدة صحيحة قطعًا.
* المشتتات معقولة ومتقاربة في الطول مع الإجابة الصحيحة.
* ممنوع: كل ما سبق / لا شيء مما سبق / أ و ب معًا / النفي المزدوج.
* ممنوع الأسئلة عن أسلوب الإلقاء أو ترتيب الكلام.
* لكل سؤال: اقتباس حرفي قصير من المصدر + شرح موجز.`;

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    questions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          text: { type: "STRING" },
          choices: { type: "ARRAY", items: { type: "STRING" } },
          correct_index: { type: "INTEGER" },
          difficulty: { type: "STRING", enum: ["easy", "medium", "hard"] },
          explanation: { type: "STRING" },
          source_quote: { type: "STRING" },
        },
        required: ["text", "choices", "correct_index", "difficulty", "explanation", "source_quote"],
      },
    },
    notes: { type: "STRING" },
  },
  required: ["questions"],
};

const CHOICE_LETTERS = ["a", "b", "c", "d"] as const;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// A failure retrying cannot fix (bad input, bad key, bad link). Retrying these
// only burns the free-tier request budget.
class PermanentError extends Error {}

function sanitize(msg: string): string {
  return msg.replace(/[?&]key=[^&\s"']*/g, "");
}

async function errBody(res: Response, max = 400): Promise<string> {
  try {
    const raw = await res.text();
    return sanitize(raw.replace(/\s+/g, " ").trim()).slice(0, max);
  } catch (_e) {
    return "";
  }
}

// 400/401/403 will not heal on retry; 429/500/503 will.
function classify(status: number, msg: string): Error {
  return status === 400 || status === 401 || status === 403
    ? new PermanentError(msg)
    : new Error(msg);
}

// Google Drive often serves "application/octet-stream" instead of the real audio
// type. Gemini then cannot take the audio path (32 tokens/sec) and instead tries
// to tokenize the raw bytes, blowing past the 1,048,576-token input limit.
// Never trust Drive's Content-Type — derive it from the filename.
const EXT_TO_MIME: Record<string, string> = {
  mp3: "audio/mpeg",  m4a: "audio/mp4",   mp4: "audio/mp4",
  aac: "audio/aac",   wav: "audio/wav",   ogg: "audio/ogg",
  oga: "audio/ogg",   opus: "audio/opus", flac: "audio/flac",
  webm: "audio/webm", amr: "audio/amr",   "3gp": "audio/3gpp",
};

function resolveAudioMime(res: Response): string {
  const header = res.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() ?? "";
  if (header.startsWith("audio/")) return header;
  const disp = res.headers.get("Content-Disposition") ?? "";
  const m = disp.match(/filename\*?=(?:UTF-8''|")?([^";]+)/i);
  const name = m ? decodeURIComponent(m[1]) : "";
  const ext = name.includes(".") ? name.split(".").pop()!.toLowerCase() : "";
  return EXT_TO_MIME[ext] ?? "audio/mpeg";
}

function driveFileId(url: string): string | null {
  for (const p of [/\/d\/([^/?#]+)/, /[?&]id=([^&#]+)/]) {
    const m = url.match(p);
    if (m) return m[1];
  }
  return null;
}

async function uploadDriveAudioToGemini(
  apiKey: string,
  sourceUrl: string,
  displayName: string,
  deadlineAt: number,
  t0: number,
): Promise<{ fileUri: string; mimeType: string }> {
  const fileId = driveFileId(sourceUrl);
  if (!fileId) throw new PermanentError("تعذّر استخراج معرّف ملف Drive من الرابط");

  const dl = await fetch(`https://drive.google.com/uc?export=download&id=${fileId}`);
  if (!dl.ok) throw new Error(`فشل تنزيل ملف الصوت من Drive (${dl.status})`);
  const rawCt = dl.headers.get("Content-Type") ?? "";
  if (rawCt.includes("text/html")) {
    throw new PermanentError('Drive رجّع صفحة تحذير بدل الملف — تأكد إن المشاركة مضبوطة على "أي شخص لديه الرابط"');
  }
  const bytes = new Uint8Array(await dl.arrayBuffer());
  if (bytes.byteLength === 0) throw new PermanentError("ملف الصوت المُنزَّل فارغ");
  const mimeType = resolveAudioMime(dl);
  console.log(
    `[worker] drive downloaded bytes=${bytes.byteLength} drive_ct=${rawCt} sent_mime=${mimeType} t=${Date.now() - t0}ms`,
  );

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
    const detail = await errBody(startRes);
    console.error(`[worker] upload start failed status=${startRes.status} body=${detail}`);
    throw classify(startRes.status, `فشل بدء رفع الملف إلى Gemini (${startRes.status}) ${detail}`);
  }
  const uploadUrl = startRes.headers.get("X-Goog-Upload-URL");
  if (!uploadUrl) throw new Error("لم يُرجِع Gemini رابط الرفع");

  const upRes = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      "Content-Length": String(bytes.byteLength),
      "X-Goog-Upload-Offset": "0",
      "X-Goog-Upload-Command": "upload, finalize",
    },
    body: bytes,
  });
  if (!upRes.ok) {
    const detail = await errBody(upRes);
    console.error(`[worker] upload failed status=${upRes.status} body=${detail}`);
    throw new Error(`فشل رفع ملف الصوت إلى Gemini (${upRes.status}) ${detail}`);
  }
  const upData = await upRes.json();
  let file = upData?.file;
  if (!file?.uri || !file?.name) throw new Error("استجابة رفع الملف غير صالحة");
  console.log(`[worker] uploaded to gemini t=${Date.now() - t0}ms`);

  while (file.state && file.state !== "ACTIVE") {
    if (file.state === "FAILED") throw new Error("فشلت معالجة ملف الصوت في Gemini");
    if (Date.now() + FILE_ACTIVE_POLL_MS > deadlineAt) throw new Error("انتهى وقت المحاولة أثناء معالجة الملف");
    await sleep(FILE_ACTIVE_POLL_MS);
    let pollRes: Response;
    try {
      pollRes = await fetch(`${GEMINI_FILES_BASE}/${file.name.replace(/^files\//, "")}?key=${apiKey}`);
    } catch (_e) {
      throw new Error("انقطع الاتصال بخدمة Gemini أثناء انتظار المعالجة");
    }
    if (!pollRes.ok) {
      const detail = await errBody(pollRes);
      throw new Error(`فشل الاستعلام عن حالة الملف (${pollRes.status}) ${detail}`);
    }
    file = await pollRes.json();
  }
  console.log(`[worker] gemini file ACTIVE t=${Date.now() - t0}ms`);
  return { fileUri: file.uri, mimeType };
}

// One Gemini call. Model rotates with the attempt number so successive retries
// do not all land on the same (possibly saturated) model.
async function callGemini(
  apiKey: string,
  model: string,
  body: unknown,
  t0: number,
): Promise<any> {
  const callStart = Date.now();
  let res: Response;
  try {
    res = await fetch(`${GEMINI_BASE}/${model}:generateContent?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (e) {
    console.error(
      `[worker] model=${model} network error after ${Date.now() - callStart}ms: ${
        sanitize(e instanceof Error ? e.message : String(e)).slice(0, 200)
      }`,
    );
    throw new Error("انقطع الاتصال بخدمة الذكاء الاصطناعي");
  }
  console.log(
    `[worker] model=${model} status=${res.status} call=${Date.now() - callStart}ms total=${Date.now() - t0}ms`,
  );
  if (!res.ok) {
    const detail = await errBody(res);
    console.error(`[worker] model=${model} status=${res.status} body=${detail}`);
    throw classify(res.status, `خطأ من خدمة الذكاء الاصطناعي (${res.status}) [${model}] ${detail}`);
  }
  return await res.json();
}

function shuffleChoices(choices: string[], correctIndex: number) {
  const idx = choices.map((_, i) => i);
  for (let i = idx.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [idx[i], idx[j]] = [idx[j], idx[i]];
  }
  return { shuffled: idx.map((i) => choices[i]), newCorrect: idx.indexOf(correctIndex) };
}

Deno.serve(async (req) => {
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // ── Auth: shared secret, not a user JWT ─────────────────────────────────
  const presented = req.headers.get("x-worker-secret") ?? "";
  const { data: secretRow } = await admin
    .from("app_secrets").select("value").eq("key", "worker_secret").maybeSingle();
  const expected = secretRow?.value as string | undefined;
  if (!expected || presented !== expected) return json({ error: "Unauthorized" }, 401);

  // ── Claim one due job (also resolves jobs abandoned by a killed worker) ───
  const { data: jobRow, error: claimErr } = await admin.rpc("claim_generation_job");
  if (claimErr) return json({ error: "claim failed", detail: claimErr.message }, 500);
  const job: any = Array.isArray(jobRow) ? jobRow[0] : jobRow;
  if (!job?.id) return json({ picked: 0 }, 200);

  const jobId = job.id as string;
  const jobType = job.job_type as string;
  const lessonId = job.lesson_id as string;
  const attempts = Number(job.attempts ?? 1);

  const t0 = Date.now();
  const deadlineAt = t0 + ATTEMPT_DEADLINE_MS;
  const model = MODEL_FALLBACK[(attempts - 1) % MODEL_FALLBACK.length];
  console.log(`[worker] claimed job=${jobId} type=${jobType} attempt=${attempts}/${MAX_ATTEMPTS}`);

  const isTranscribe = jobType === "transcribe";
  if (isTranscribe) {
    await admin.from("lessons").update({ transcript_status: "running" }).eq("id", lessonId);
  }

  const fail = async (message: string, permanent: boolean) => {
    const terminal = permanent || attempts >= MAX_ATTEMPTS;
    if (terminal) {
      if (isTranscribe) {
        await admin
          .from("lessons")
          .update({
            transcript_status: "failed",
            transcript_error: permanent ? message : TERMINAL_MESSAGE,
          })
          .eq("id", lessonId);
      }
      await admin.from("generation_jobs")
        .update({ status: "failed", error_message: message, updated_at: new Date().toISOString() })
        .eq("id", jobId);
      console.log(`[worker] job=${jobId} TERMINAL permanent=${permanent} attempts=${attempts}`);
      return json({ picked: 1, type: jobType, outcome: "failed", permanent, attempts }, 200);
    }

    const waitMin = BACKOFF_MIN[attempts - 1] ?? 60;
    await admin.from("generation_jobs")
      .update({
        status: "queued",
        next_attempt_at: new Date(Date.now() + waitMin * 60_000).toISOString(),
        error_message: message,
        updated_at: new Date().toISOString(),
      })
      .eq("id", jobId);
    if (isTranscribe) {
      await admin.from("lessons")
        .update({ transcript_status: "queued", transcript_error: null })
        .eq("id", lessonId);
    }
    console.log(`[worker] job=${jobId} REQUEUED attempt=${attempts} next_in=${waitMin}min`);
    return json({ picked: 1, type: jobType, outcome: "requeued", attempts, next_attempt_in_min: waitMin }, 200);
  };

  try {
    const { data: secret } = await admin
      .from("app_secrets").select("value").eq("key", "gemini_api_key").maybeSingle();
    const GEMINI_API_KEY = secret?.value as string | undefined;
    if (!GEMINI_API_KEY) throw new PermanentError("مفتاح Gemini غير مضبوط في إعدادات الأدمن");

    // ══ TRANSCRIBE ════════════════════════════════════════════════════
    if (isTranscribe) {
      const sourceType = job.source_type as string | null;
      const sourceUrl = job.source_url as string | null;
      if (!sourceUrl || (sourceType !== "youtube" && sourceType !== "drive_audio")) {
        throw new PermanentError("بيانات المصدر ناقصة أو غير صالحة");
      }

      let filePart: Record<string, unknown>;
      if (sourceType === "youtube") {
        filePart = { file_data: { file_uri: sourceUrl.trim() } };
      } else {
        const { fileUri, mimeType } = await uploadDriveAudioToGemini(
          GEMINI_API_KEY, sourceUrl.trim(), lessonId, deadlineAt, t0,
        );
        filePart = { file_data: { file_uri: fileUri, mime_type: mimeType } };
      }

      const data = await callGemini(GEMINI_API_KEY, model, {
        contents: [{ role: "user", parts: [filePart, { text: TRANSCRIBE_PROMPT }] }],
        generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS },
      }, t0);

      const parts = data?.candidates?.[0]?.content?.parts;
      const transcript = Array.isArray(parts)
        ? parts.map((p: any) => p?.text ?? "").join("").trim() : "";
      if (!transcript) {
        const finish = data?.candidates?.[0]?.finishReason ?? "";
        const block = data?.promptFeedback?.blockReason ?? "";
        throw new Error(`أعاد النموذج نصًا فارغًا [${model}] finish=${finish} block=${block}`);
      }

      await admin.from("lessons").update({
        transcript,
        transcript_status: "ready",
        transcript_error: null,
        transcript_generated_at: new Date().toISOString(),
      }).eq("id", lessonId);
      await admin.from("generation_jobs")
        .update({ status: "done", error_message: null, updated_at: new Date().toISOString() })
        .eq("id", jobId);

      console.log(`[worker] job=${jobId} DONE attempt=${attempts} chars=${transcript.length}`);
      return json({ picked: 1, type: jobType, outcome: "done", attempts, chars: transcript.length }, 200);
    }

    // ══ GENERATE QUESTIONS ════════════════════════════════════════════
    if (jobType !== "generate_questions") {
      throw new PermanentError(`نوع وظيفة غير معروف: ${jobType}`);
    }

    // Prefer the text the admin submitted; fall back to the stored transcript.
    let sourceText = (job.input_text as string | null)?.trim() ?? "";
    if (!sourceText) {
      const { data: lesson } = await admin
        .from("lessons").select("transcript").eq("id", lessonId).maybeSingle();
      sourceText = (lesson?.transcript as string | null)?.trim() ?? "";
    }
    if (!sourceText) throw new PermanentError("لا يوجد نص مصدر لتوليد الأسئلة");

    const requestedCount = Number(job.requested_count ?? 0);
    if (!requestedCount || requestedCount <= 0) {
      throw new PermanentError("عدد الأسئلة المطلوب غير صالح");
    }
    const mix = (job.difficulty_mix ?? {}) as Record<string, number>;
    const share = (n: unknown) => Math.max(0, Math.round(Number(n) || 0));

    const userPrompt =
      `النص المصدر:\n"""\n${sourceText}\n"""\n\n` +
      `المطلوب: ${requestedCount} أسئلة، بتوزيع تقريبي: ` +
      `${share(mix.easy)} سهل، ${share(mix.medium)} متوسط، ${share(mix.hard)} صعب. ` +
      `اجتهد للوصول إلى هذا العدد دون اختلاق أي معلومة غير موجودة في النص.`;

    const data = await callGemini(GEMINI_API_KEY, model, {
      systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
      contents: [{ role: "user", parts: [{ text: userPrompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
      },
    }, t0);

    const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!raw) throw new Error("أعاد النموذج استجابة فارغة");

    let questions: any[];
    try {
      const parsed = JSON.parse(raw);
      questions = Array.isArray(parsed?.questions) ? parsed.questions : [];
    } catch (_e) {
      throw new Error("تعذّر تحليل استجابة النموذج");
    }
    if (questions.length === 0) throw new Error("أعاد النموذج استجابة بلا أسئلة");

    const { data: maxRow } = await admin
      .from("lesson_quiz_questions")
      .select("order_index")
      .eq("lesson_id", lessonId)
      .order("order_index", { ascending: false })
      .limit(1)
      .maybeSingle();
    let nextOrder = (maxRow?.order_index ?? -1) + 1;

    const rows = questions
      .slice(0, requestedCount)
      .filter((q) =>
        Array.isArray(q?.choices) && q.choices.length === 4 &&
        typeof q?.correct_index === "number" && q.correct_index >= 0 && q.correct_index <= 3
      )
      .map((q) => {
        const { shuffled, newCorrect } = shuffleChoices(q.choices, q.correct_index);
        return {
          lesson_id: lessonId,
          order_index: nextOrder++,
          question_text: q.text,
          choice_a: shuffled[0],
          choice_b: shuffled[1],
          choice_c: shuffled[2],
          choice_d: shuffled[3],
          correct_choice: CHOICE_LETTERS[newCorrect],
          source: "ai_generated",
          ai_review_status: "pending",
          difficulty: q.difficulty ?? null,
          explanation: q.explanation ?? null,
          source_quote: q.source_quote ?? null,
        };
      });

    if (rows.length === 0) throw new Error("أعاد النموذج أسئلة غير صالحة الصياغة");

    const { data: ins, error: insErr } = await admin
      .from("lesson_quiz_questions").insert(rows).select("id");
    // A DB rejection is our bug, not Gemini's; retrying will reproduce it.
    if (insErr) throw new PermanentError(`فشل حفظ الأسئلة: ${insErr.message}`);

    const inserted = ins?.length ?? 0;
    await admin.from("generation_jobs").update({
      status: "done",
      result_count: inserted,
      error_message: null,
      updated_at: new Date().toISOString(),
    }).eq("id", jobId);

    console.log(`[worker] job=${jobId} DONE attempt=${attempts} questions=${inserted}`);
    return json({ picked: 1, type: jobType, outcome: "done", attempts, inserted }, 200);
  } catch (err) {
    const message = sanitize(err instanceof Error ? err.message : String(err));
    console.error(`[worker] job=${jobId} attempt=${attempts} error: ${message}`);
    return await fail(message, err instanceof PermanentError);
  }
});
