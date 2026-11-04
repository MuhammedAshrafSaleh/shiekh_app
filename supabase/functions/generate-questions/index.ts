// supabase/functions/generate-questions/index.ts
//
// ENQUEUE ONLY. This function no longer talks to Gemini.
//
// Measured on the live Ahmed project before this change: 15 done / 10 failed
// (38% failure), slowest SUCCESS 149s against a ~150s platform wall clock, 86s
// average. There was no room for a second attempt inside one invocation, and
// when the platform killed the function the catch block never ran, leaving jobs
// stuck at 'running' forever.
//
// Now it records the request and returns in ~1s. generation-worker, driven by
// pg_cron every 2 minutes, does the work and retries with backoff across ~8
// hours. See docs: docs/AI_QUEUE.md

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

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

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // Fail fast while the admin is still looking at the screen, rather than
  // queueing work that every attempt would reject.
  const { data: secret } = await admin
    .from("app_secrets")
    .select("value")
    .eq("key", "gemini_api_key")
    .maybeSingle();
  if (!secret?.value) return json({ error: "AI_KEY_MISSING" }, 400);

  // Supersede any still-pending generation for this lesson, so pressing the
  // button twice does not queue two batches of questions for the same lesson.
  await admin
    .from("generation_jobs")
    .update({ status: "failed", error_message: "تم استبدالها بطلب أحدث" })
    .eq("lesson_id", lesson_id)
    .eq("job_type", "generate_questions")
    .in("status", ["queued", "running"]);

  const { data: job, error: jobErr } = await admin
    .from("generation_jobs")
    .insert({
      lesson_id,
      job_type: "generate_questions",
      status: "queued",
      attempts: 0,
      next_attempt_at: new Date().toISOString(),
      requested_count,
      difficulty_mix,
      input_text: transcript_text,
      created_by: userData.user.id,
    })
    .select("id")
    .single();
  if (jobErr || !job) return json({ error: "Failed to create job", detail: jobErr?.message }, 500);

  console.log(`[enqueue] questions lesson=${lesson_id} count=${requested_count} job=${job.id}`);

  return json({ job_id: job.id, status: "queued" }, 202);
});
