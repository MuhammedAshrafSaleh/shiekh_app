-- 0025_async_transcription.sql
-- Move transcription off the 150s request path and onto a retry queue.
-- 'queued' is already allowed by generation_jobs_status_check and
-- lessons_transcript_status_check, so no constraint changes are needed.
--
-- APPLIED TO Medhat-Abdelaziz 2026-11-03 as version 20261103054751.
-- This file is the exact SQL that ran. Do not "improve" it — it must stay
-- reproducible against the live project.

alter table public.generation_jobs
  add column if not exists attempts        int         not null default 0,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists source_type     text,
  add column if not exists source_url      text;

create index if not exists generation_jobs_due_idx
  on public.generation_jobs (next_attempt_at)
  where status = 'queued' and job_type = 'transcribe';

-- Atomically hand exactly one due transcribe job to a worker.
-- Also recovers jobs whose worker was killed mid-flight (left 'running').
-- NOTE: superseded by claim_generation_job() in 0027; kept here so the
-- migration history replays faithfully on a new project.
create or replace function public.claim_transcribe_job()
returns public.generation_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  j public.generation_jobs;
begin
  update public.generation_jobs
     set status = 'queued', updated_at = now()
   where job_type = 'transcribe'
     and status = 'running'
     and updated_at < now() - interval '5 minutes';

  update public.generation_jobs g
     set status = 'running', attempts = g.attempts + 1, updated_at = now()
   where g.id = (
     select id
       from public.generation_jobs
      where job_type = 'transcribe'
        and status = 'queued'
        and next_attempt_at <= now()
      order by next_attempt_at
      limit 1
      for update skip locked
   )
  returning g.* into j;

  return j;
end;
$$;

-- Service role only: the worker is the sole caller.
revoke execute on function public.claim_transcribe_job() from public;
revoke execute on function public.claim_transcribe_job() from anon;
revoke execute on function public.claim_transcribe_job() from authenticated;

-- Shared secret the cron job presents to the worker function.
insert into public.app_secrets (key, value)
values (
  'worker_secret',
  replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
)
on conflict (key) do nothing;
