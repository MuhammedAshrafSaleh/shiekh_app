// supabase/functions/transcribe-lesson/index.ts
//
// ENQUEUE ONLY. This function no longer talks to Gemini.
//
// It used to run the whole transcription inside the request, which gave Gemini
// ~150s of platform wall clock to succeed while an admin waited at a spinner.
// Gemini returns HTTP 503 (capacity) for long audio on the free tier and each
// call costs 20-45s, so only ~4 attempts fit before the platform killed the
// function mid-flight — which also left lessons stuck at 'running' forever,
// because the catch block never ran.
//
// Now it records the request and returns in ~2s. transcribe-worker, driven by
// pg_cron every 2 minutes, does the actual work and retries with backoff across
// ~8 hours. See docs: docs/AI_QUEUE.md

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

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // Fail fast while the admin is still looking at the screen, rather than
  // queueing work that every attempt would reject.
  const { data: secret } = await admin
    .from("app_secrets")
    .select("value")
    .eq("key", "gemini_api_key")
    .maybeSingle();
  if (!secret?.value) return json({ error: "AI_KEY_MISSING" }, 400);

  // Supersede any still-pending transcribe job for this lesson, so pressing the
  // button twice does not put two jobs for the same lesson in the queue.
  await admin
    .from("generation_jobs")
    .update({ status: "failed", error_message: "تم استبدالها بطلب أحدث" })
    .eq("lesson_id", lesson_id)
    .eq("job_type", "transcribe")
    .in("status", ["queued", "running"]);

  const { data: job, error: jobErr } = await admin
    .from("generation_jobs")
    .insert({
      lesson_id,
      job_type: "transcribe",
      status: "queued",
      attempts: 0,
      next_attempt_at: new Date().toISOString(),
      source_type,
      source_url: source_url.trim(),
      created_by: userData.user.id,
    })
    .select("id")
    .single();
  if (jobErr || !job) return json({ error: "Failed to create job", detail: jobErr?.message }, 500);

  await admin
    .from("lessons")
    .update({ transcript_status: "queued", transcript_error: null })
    .eq("id", lesson_id);

  console.log(`[enqueue] lesson=${lesson_id} source=${source_type} job=${job.id}`);

  return json({ job_id: job.id, status: "queued" }, 202);
});
