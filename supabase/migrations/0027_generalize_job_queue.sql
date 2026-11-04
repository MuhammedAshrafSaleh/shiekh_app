-- 0027_generalize_job_queue.sql
-- Extend the retry queue from 'transcribe' to 'generate_questions'.
--
-- APPLIED TO Medhat-Abdelaziz 2026-11-03 as version 20261103140702.
--
-- Why: on the live Ahmed project, generate_questions was 15 done / 10 failed
-- (38% failure) and the slowest SUCCESS took 149s against a ~150s platform
-- wall clock, with an 86s average. There is no room for a second attempt
-- inside one invocation, so shortening the backoff cannot help — the work has
-- to move off the request path, exactly as transcription did.

alter table public.generation_jobs
  add column if not exists input_text text;

-- The worker now claims any due job, not just transcribe.
drop index if exists public.generation_jobs_due_idx;
create index if not exists generation_jobs_due_idx
  on public.generation_jobs (next_attempt_at)
  where status = 'queued';

create or replace function public.claim_generation_job()
returns public.generation_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  j public.generation_jobs;
begin
  -- Rows written by the old synchronous design carry no queue payload, so a
  -- worker could never finish them. Resolve them instead of looping forever.
  update public.generation_jobs
     set status        = 'failed',
         error_message = coalesce(error_message, 'انتهى وقت المعالجة قبل رد الخدمة'),
         updated_at    = now()
   where status = 'running'
     and updated_at < now() - interval '5 minutes'
     and source_url is null
     and input_text is null;

  -- Recover jobs whose worker was killed mid-flight.
  update public.generation_jobs
     set status = 'queued', updated_at = now()
   where status = 'running'
     and updated_at < now() - interval '5 minutes';

  update public.generation_jobs g
     set status = 'running', attempts = g.attempts + 1, updated_at = now()
   where g.id = (
     select id
       from public.generation_jobs
      where status = 'queued'
        and next_attempt_at <= now()
      order by next_attempt_at
      limit 1
      for update skip locked
   )
  returning g.* into j;

  return j;
end;
$$;

revoke execute on function public.claim_generation_job() from public;
revoke execute on function public.claim_generation_job() from anon;
revoke execute on function public.claim_generation_job() from authenticated;

-- Superseded by claim_generation_job().
drop function if exists public.claim_transcribe_job();
