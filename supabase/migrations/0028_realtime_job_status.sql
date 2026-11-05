-- 0028_realtime_job_status.sql
-- The admin UI subscribes to job progress instead of polling, now that AI work
-- runs in the background and can take minutes to hours.
--
-- APPLIED TO Medhat-Abdelaziz 2026-11-03 as version 20261103141408.
--
-- Realtime only forwards changes for tables in the supabase_realtime
-- publication. Without this, the app would silently never receive an update and
-- would look broken exactly as it did before.
-- RLS still applies to Realtime, so only rows a user may already read are sent.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'lessons'
  ) then
    alter publication supabase_realtime add table public.lessons;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'generation_jobs'
  ) then
    alter publication supabase_realtime add table public.generation_jobs;
  end if;
end $$;

-- Realtime sends only the changed columns unless the row identity is full, and
-- the app needs lesson_id / job_type / status together to route an update.
alter table public.generation_jobs replica identity full;
