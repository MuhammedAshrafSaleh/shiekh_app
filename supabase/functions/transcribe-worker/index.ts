// supabase/functions/transcribe-worker/index.ts
//
// RETIRED. Superseded by generation-worker, which handles both 'transcribe' and
// 'generate_questions' jobs. The RPC this function used (claim_transcribe_job)
// was dropped in migration 0027_generalize_job_queue.sql.
//
// Kept only as a tombstone because Edge Functions cannot be deleted from the
// management API — delete it in the Supabase dashboard
// (Edge Functions → transcribe-worker → Delete) and remove this file.

Deno.serve(() =>
  new Response(
    JSON.stringify({
      error: "Gone",
      detail: "transcribe-worker was replaced by generation-worker.",
    }),
    { status: 410, headers: { "Content-Type": "application/json" } },
  )
);
