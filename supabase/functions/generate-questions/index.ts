// supabase/functions/generate-questions/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Static config (NOT the caller-controlled generation params) ──────────────
const MODEL_FALLBACK = ["gemini-flash-latest", "gemini-3.6-flash", "gemini-3.8-flash"];
const RETRY_BACKOFF_MS = [10_000, 20_000, 30_000]; // per-model, on HTTP 503 only
const NUM_CHUNKS = 1; // single full-transcript call — coverage is handled by the prompt, not chunking
const OVERALL_DEADLINE_MS = 100_000; // wall-clock cap for Gemini phase (~50s margin under the 150s platform limit)
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
عدد الأسئلة حد أقصى وليس التزامًا. أسئلة قليلة سليمة خير من أسئلة كثيرة فيها اختلاق.

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
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Split on whitespace into NUM_CHUNKS roughly equal word-count chunks; never cut mid-word.
function chunkTranscript(text: string, numChunks: number): string[] {
  const words = text.trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return [];
  const per = Math.ceil(words.length / numChunks);
  const chunks: string[] = [];
  for (let i = 0; i < words.length; i += per) {
    chunks.push(words.slice(i, i + per).join(" "));
  }
  return chunks;
}

// Fisher–Yates shuffle of the 4 choices; returns shuffled choices + new correct index.
function shuffleChoices(choices: string[], correctIndex: number) {
  const idx = choices.map((_, i) => i);
  for (let i = idx.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [idx[i], idx[j]] = [idx[j], idx[i]];
  }
  const shuffled = idx.map((i) => choices[i]);
  const newCorrect = idx.indexOf(correctIndex);
  return { shuffled, newCorrect };
}

// Per-chunk difficulty target from the request-wide counts object, divided across chunks.
function perChunkTargets(mix: Record<string, number>, numChunks: number) {
  const share = (n: number) => Math.max(0, Math.round((Number(n) || 0) / numChunks));
  return { easy: share(mix.easy), medium: share(mix.medium), hard: share(mix.hard) };
}

// Call Gemini for one chunk with model fallback + 503 retry/backoff, honoring the deadline.
async function generateForChunk(
  apiKey: string,
  chunk: string,
  targets: { easy: number; medium: number; hard: number },
  chunkCap: number,
  deadlineAt: number,
): Promise<any[]> {
  const userPrompt =
    `النص المصدر:\n"""\n${chunk}\n"""\n\n` +
    `المطلوب: حتى ${chunkCap} أسئلة بحد أقصى، بتوزيع تقريبي: ` +
    `${targets.easy} سهل، ${targets.medium} متوسط، ${targets.hard} صعب. ` +
    `التزم بقاعدة العدد: الأفضل أقل مع الدقة.`;

  const body = {
    systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

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
        break; // network error → next model immediately
      }

      if (res.status === 503) {
        const wait = RETRY_BACKOFF_MS[attempt];
        if (attempt === RETRY_BACKOFF_MS.length - 1) break; // retries exhausted → next model
        if (Date.now() + wait > deadlineAt) throw new Error("deadline_exceeded");
        await sleep(wait);
        continue;
      }

      if (!res.ok) break; // non-503 error → next model immediately

      const data = await res.json();
      const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!raw) return [];
      try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed?.questions) ? parsed.questions : [];
      } catch (_e) {
        return [];
      }
    }
  }
  return []; // all models/retries failed for this chunk — skip it, keep the rest
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) return json({ error: "GEMINI_API_KEY not configured" }, 500);

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

  // ── Validate input (caller-controlled; no defaults) ────────────────────────
  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const { lesson_id, transcript_text, requested_count, difficulty_mix } = payload ?? {};

  if (!lesson_id || typeof lesson_id !== "string") return json({ error: "lesson_id is required" }, 400);
  if (!transcript_text || typeof transcript_text !== "string" || !transcript_text.trim())
    return json({ error: "transcript_text is required" }, 400);
  if (typeof requested_count !== "number" || requested_count <= 0)
    return json({ error: "requested_count is required and must be a positive number" }, 400);
  if (!difficulty_mix || typeof difficulty_mix !== "object")
    return json({ error: "difficulty_mix is required" }, 400);

  // ── Service-role client for all writes ─────────────────────────────────────
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // ── Create the job row (running) ───────────────────────────────────────────
  const { data: job, error: jobErr } = await admin
    .from("generation_jobs")
    .insert({
      lesson_id,
      job_type: "generate_questions",
      status: "running",
      requested_count,
      difficulty_mix,
      created_by: userData.user.id,
    })
    .select("id")
    .single();
  if (jobErr || !job) return json({ error: "Failed to create job", detail: jobErr?.message }, 500);

  const jobId = job.id as string;

  try {
    const chunks = chunkTranscript(transcript_text, NUM_CHUNKS);
    if (chunks.length === 0) throw new Error("transcript produced no chunks");

    const targets = perChunkTargets(difficulty_mix, chunks.length);
    // Single chunk (NUM_CHUNKS=1) → requested_count is passed straight through.
    const chunkCap = Math.ceil(requested_count / chunks.length);
    const startedAt = Date.now();
    const deadlineAt = startedAt + OVERALL_DEADLINE_MS;

    // Collect all chunks' questions (sequential — respects backoff + deadline).
    // On a deadline hit, annotate the error with elapsed time so we can see where
    // the wall-clock actually went next time.
    const collected: any[] = [];
    for (const chunk of chunks) {
      try {
        const qs = await generateForChunk(GEMINI_API_KEY, chunk, targets, chunkCap, deadlineAt);
        collected.push(...qs);
      } catch (e) {
        if (e instanceof Error && e.message === "deadline_exceeded") {
          const elapsed = Math.round((Date.now() - startedAt) / 1000);
          throw new Error(`deadline_exceeded after ${elapsed}s`);
        }
        throw e;
      }
    }

    // Cap the total to requested_count.
    const limited = collected.slice(0, requested_count);

    // Continue order_index after the current max for this lesson.
    const { data: maxRow } = await admin
      .from("lesson_quiz_questions")
      .select("order_index")
      .eq("lesson_id", lesson_id)
      .order("order_index", { ascending: false })
      .limit(1)
      .maybeSingle();
    let nextOrder = (maxRow?.order_index ?? -1) + 1;

    // Build insert rows: shuffle choices, remap correct_choice.
    const rows = limited
      .filter((q) => Array.isArray(q?.choices) && q.choices.length === 4 &&
        typeof q?.correct_index === "number" && q.correct_index >= 0 && q.correct_index <= 3)
      .map((q) => {
        const { shuffled, newCorrect } = shuffleChoices(q.choices, q.correct_index);
        return {
          lesson_id,
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

    let inserted: any[] = [];
    if (rows.length > 0) {
      const { data: ins, error: insErr } = await admin
        .from("lesson_quiz_questions")
        .insert(rows)
        .select();
      if (insErr) throw new Error(`insert failed: ${insErr.message}`);
      inserted = ins ?? [];
    }

    await admin
      .from("generation_jobs")
      .update({ status: "done", result_count: inserted.length })
      .eq("id", jobId);

    return json({ job_id: jobId, inserted_count: inserted.length, questions: inserted });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    // Always mark the job failed — whatever was inserted before the error is kept.
    await admin
      .from("generation_jobs")
      .update({ status: "failed", error_message: message })
      .eq("id", jobId);
    return json({ job_id: jobId, error: message }, 500);
  }
});
