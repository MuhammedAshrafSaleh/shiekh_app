-- ============================================================
-- Sheikhy — Companion Migration 0011_ai_question_generation.sql
-- Additive only — runs on top of 0001–0010.
-- Run this ONCE in Supabase SQL Editor.
--
-- Adds the database layer for AI-assisted quiz-question generation:
--   1. Extends lesson_quiz_questions with provenance + review columns.
--   2. Extends lessons with transcript pipeline columns.
--   3. Creates generation_jobs table (admin-only, RLS-guarded).
--   4. Replaces lesson_quiz_questions_student view to filter out
--      questions still under AI review (ai_review_status != 'approved').
--
-- Safe defaults: existing rows get source='manual',
-- ai_review_status='approved' — zero behavior change for current data.
-- Does NOT touch final_exam_questions (deferred).
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Extend lesson_quiz_questions
-- ────────────────────────────────────────────────────────────

alter table public.lesson_quiz_questions
  add column if not exists source text not null default 'manual'
    check (source in ('manual', 'ai_generated', 'edited_by_admin')),

  add column if not exists ai_review_status text not null default 'approved'
    check (ai_review_status in ('pending', 'approved', 'rejected')),

  -- Optional metadata columns (nullable, no behavioral impact on existing rows)
  add column if not exists difficulty text
    check (difficulty in ('easy', 'medium', 'hard')),

  add column if not exists explanation text,

  add column if not exists source_quote text,

  add column if not exists reviewed_by uuid
    references public.users(id),

  add column if not exists reviewed_at timestamptz;

-- ────────────────────────────────────────────────────────────
-- 2. Extend lessons with transcript pipeline columns
-- ────────────────────────────────────────────────────────────

alter table public.lessons
  add column if not exists transcript text,

  add column if not exists transcript_status text not null default 'none'
    check (transcript_status in ('none', 'queued', 'running', 'ready', 'failed')),

  add column if not exists transcript_error text,

  add column if not exists transcript_generated_at timestamptz;

-- ────────────────────────────────────────────────────────────
-- 3. generation_jobs — tracks transcribe + generate_questions jobs
-- ────────────────────────────────────────────────────────────

create table if not exists public.generation_jobs (
  id              uuid        primary key default gen_random_uuid(),
  lesson_id       uuid        not null references public.lessons(id) on delete cascade,
  job_type        text        not null check (job_type in ('transcribe', 'generate_questions')),
  status          text        not null default 'queued'
                              check (status in ('queued', 'running', 'done', 'failed')),
  requested_count int,
  difficulty_mix  jsonb,
  result_count    int,
  error_message   text,
  created_by      uuid        references public.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.generation_jobs enable row level security;

-- Admin can do everything; no student visibility at all.
create policy "generation_jobs_admin_all" on public.generation_jobs
  for all using (public.is_admin()) with check (public.is_admin());

-- Auto-stamp updated_at on every update (reuses the shared function from schema.sql).
create trigger trg_generation_jobs_updated_at
  before update on public.generation_jobs
  for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────
-- 4. Replace lesson_quiz_questions_student view
--    Identical to the 0005 definition + one extra condition:
--    q.ai_review_status = 'approved'
--    Existing rows default to 'approved' so no data is hidden.
-- ────────────────────────────────────────────────────────────

create or replace view public.lesson_quiz_questions_student
  with (security_invoker = false)
as
select
  q.id,
  q.lesson_id,
  q.order_index,
  q.question_text,
  q.choice_a,
  q.choice_b,
  q.choice_c,
  q.choice_d,
  q.created_at
from public.lessons l
join public.lesson_quiz_questions q on q.lesson_id = l.id
where l.status = 'published'
  and not public.is_guest()
  and q.ai_review_status = 'approved';

-- Re-apply the existing grant (create or replace resets it).
grant select on public.lesson_quiz_questions_student to authenticated;

-- ============================================================
-- Rollback (run manually if needed — migrations are never auto-rolled back)
--
-- drop view if exists public.lesson_quiz_questions_student;
-- (then re-apply the 0005 definition without the ai_review_status clause)
--
-- drop trigger if exists trg_generation_jobs_updated_at on public.generation_jobs;
-- drop table if exists public.generation_jobs;
--
-- alter table public.lessons
--   drop column if exists transcript,
--   drop column if exists transcript_status,
--   drop column if exists transcript_error,
--   drop column if exists transcript_generated_at;
--
-- alter table public.lesson_quiz_questions
--   drop column if exists source,
--   drop column if exists ai_review_status,
--   drop column if exists difficulty,
--   drop column if exists explanation,
--   drop column if exists source_quote,
--   drop column if exists reviewed_by,
--   drop column if exists reviewed_at;
-- ============================================================
