-- ============================================================
-- docs/full_setup_part5.sql — Sheikhy setup, Part 5 of 5
-- ============================================================
-- Migrations 0025–0028  (AI job queue: retry columns, claim RPC,
-- pg_cron + pg_net, Realtime publication)
-- Run the five parts in order (part1 → … → part5); each part
-- assumes every earlier part already succeeded.
--
-- WHY THIS PART EXISTS SEPARATELY
-- Parts 1–4 predate the AI job queue. Transcription and question
-- generation no longer run inside the Edge Function request; they
-- are enqueued and processed by a background worker driven by
-- pg_cron. Without this part the app accepts the request, shows
-- "في الطابور", and nothing ever picks it up — with no error
-- anywhere to lead you to the cause.
-- For WHY it is built this way, see docs/AI_QUEUE.md.
--
-- [!] Elevated-privilege statements (postgres role; fine in the
--     Supabase SQL Editor):
--       • CREATE EXTENSION pg_cron / pg_net  (0026)
--       • ALTER PUBLICATION supabase_realtime (0028)
--
-- [!] STILL REQUIRED AFTER THIS FILE
--     1. Deploy the three Edge Functions, with generation-worker
--        at verify_jwt = false.
--     2. Create the cron schedule — it embeds this project's ref
--        in a URL, so it cannot live in a migration.
--     See docs/WHITELABEL.md → "Step 12 — AI job queue".
--
-- Generated: 2026-11-05
-- ============================================================


-- ============================================================
-- SOURCE: supabase/migrations/0025_async_transcription.sql
-- ============================================================
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


-- ============================================================
-- SOURCE: supabase/migrations/0026_enable_cron_net.sql
-- ============================================================
-- 0026_enable_cron_net.sql
-- pg_cron drives the background worker; pg_net lets it call the Edge Function.
--
-- APPLIED TO Medhat-Abdelaziz 2026-11-03 as version 20261103055026.
--
-- After this runs, the schedule itself still has to be created once per
-- project, because it embeds that project's ref in the URL. See
-- docs/WHITELABEL.md, "AI job queue".

create extension if not exists pg_cron;
create extension if not exists pg_net;


-- ============================================================
-- SOURCE: supabase/migrations/0027_generalize_job_queue.sql
-- ============================================================
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


-- ============================================================
-- SOURCE: supabase/migrations/0028_realtime_job_status.sql
-- ============================================================
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


-- ============================================================
-- SOURCE: supabase/migrations/0029_levels.sql
-- ============================================================
-- ============================================================
-- Sheikhy — 0029_levels.sql
-- Browse-by-level feature. Additive only. Safe to re-run (idempotent).
-- Runs on top of the full 0000..0028 sequence.
-- ============================================================

-- ------------------------------------------------------------
-- 1. levels — academic years / levels. Admin-managed, own display order.
--    Sibling of public.sections → mirrors its uuid generator.
-- ------------------------------------------------------------
create table if not exists public.levels (
  id         uuid primary key default extensions.uuid_generate_v4(),
  name       text    not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
comment on table public.levels is 'المستويات الدراسية (السنوات) لتصفية الكتب حسب المستوى';

-- ------------------------------------------------------------
-- 2. books gains an optional single-level link + per-level ordering.
--    A book belongs to at most one level (or none).
-- ------------------------------------------------------------
alter table public.books add column if not exists level_id uuid
  references public.levels(id) on delete set null;
alter table public.books add column if not exists level_order integer;

comment on column public.books.level_id    is 'المستوى الدراسي المرتبط بالكتاب (اختياري، مستوى واحد كحد أقصى)';
comment on column public.books.level_order  is 'ترتيب الكتاب داخل المستوى';

-- ------------------------------------------------------------
-- 3. Indexes
--    uq_levels_name: case-insensitive unique level name (trimmed) — blocks
--    accidental duplicates. The app maps violation 23505 to an Arabic message.
-- ------------------------------------------------------------
create unique index if not exists uq_levels_name
  on public.levels (lower(btrim(name)));
create index if not exists idx_levels_sort
  on public.levels (sort_order);
create index if not exists idx_books_level
  on public.books (level_id, level_order);

-- ------------------------------------------------------------
-- 4. RLS — mirror sections exactly: readable by all, writable by admins only.
-- ------------------------------------------------------------
alter table public.levels enable row level security;

drop policy if exists "levels_select_all" on public.levels;
create policy "levels_select_all" on public.levels
  for select using (true);

drop policy if exists "levels_admin_write" on public.levels;
create policy "levels_admin_write" on public.levels
  using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 5. Hard-delete hygiene. ON DELETE SET NULL clears books.level_id but leaves
--    stale books.level_order; this trigger nulls it so no orphan order remains.
-- ------------------------------------------------------------
create or replace function public.clear_book_level_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.books set level_order = null where level_id = OLD.id;
  return OLD;
end;
$$;

drop trigger if exists trg_levels_clear_book_order on public.levels;
create trigger trg_levels_clear_book_order
  before delete on public.levels
  for each row
  execute function public.clear_book_level_order();

-- ------------------------------------------------------------
-- 6. Transactional reorder RPCs (mirror reorder_lessons; security invoker, so
--    the admin RLS UPDATE policy applies). Whole call rolls back on any failure.
-- ------------------------------------------------------------
create or replace function public.reorder_levels(p_updates jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.levels
    set    sort_order = (v_row->>'sort_order')::int
    where  id = (v_row->>'id')::uuid;
  end loop;
end;
$$;
grant execute on function public.reorder_levels(jsonb) to authenticated;

-- reorder_level_books is SCOPED to one level: the `and level_id = p_level_id`
-- guard means a malformed or hostile payload cannot reorder another level's books.
create or replace function public.reorder_level_books(p_level_id uuid, p_updates jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.books
    set    level_order = (v_row->>'level_order')::int
    where  id = (v_row->>'id')::uuid
      and  level_id = p_level_id;
  end loop;
end;
$$;
grant execute on function public.reorder_level_books(uuid, jsonb) to authenticated;
