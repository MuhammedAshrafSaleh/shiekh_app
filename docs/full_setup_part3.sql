-- ============================================================
-- docs/full_setup_part3.sql — Sheikhy setup, Part 3 of 5
-- ============================================================
-- Migrations 0009–0016  (columns, AI, media, entitlement hardening)
-- Run the five parts in order (part1 → part2 → part3 → part4 → part5);
-- each part assumes every earlier part already succeeded.
--
-- [!] Elevated-privilege statements (postgres role; fine in the
--     Supabase SQL Editor):
--       • (none in this part)
-- Generated: 2026-10-26
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0009_split_media_position.sql
-- ============================================================
-- 0009_split_media_position.sql
-- Additive migration: split lesson resume position into per-medium columns.
--
-- Previously video and audio shared lesson_progress.last_position_seconds, so the
-- audio position-save timer overwrote the video resume point and vice-versa. Give
-- each medium its own column. last_position_seconds is kept (dormant) for now — a
-- later cleanup can drop it once no reads remain.

alter table lesson_progress
  add column if not exists video_position_seconds int not null default 0,
  add column if not exists audio_position_seconds int not null default 0;

-- Backfill: existing saved positions are assumed to be video positions.
update lesson_progress
  set video_position_seconds = last_position_seconds
  where last_position_seconds > 0;

-- ============================================================
-- SOURCE: supabase/migrations/0010_student_questions_admin_delete.sql
-- ============================================================
-- 0010_student_questions_admin_delete.sql
-- Additive-only. Adds admin-only DELETE on student_questions so the admin can
-- delete individual questions and clear all questions for a book.
-- The base schema only defined select/insert/admin-update policies.

drop policy if exists "questions_admin_delete" on public.student_questions;
create policy "questions_admin_delete" on public.student_questions
  for delete using (public.is_admin());

-- ============================================================
-- SOURCE: supabase/migrations/0011_ai_question_generation.sql
-- ============================================================
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

-- ============================================================
-- SKIPPED: supabase/migrations/0011_test_harness.sql
--   Reason: BEGIN…ROLLBACK test script — produces no permanent state; skipped
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0012_lesson_pdfs.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0012_lesson_pdfs.sql   (Multiple PDFs per lesson)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: replace the single lessons.pdf_url with a proper child table so a
-- lesson can carry several titled PDFs (transcript, the book itself, handouts…).
-- Mirrors the existing lesson_quiz_questions pattern: a per-lesson child table
-- with its own RLS (students read published+entitled content, admin writes).
--
-- lessons.pdf_url is KEPT as a DEPRECATED compatibility shim for legacy app
-- builds. It is maintained solely by the trigger below (auto-mirror of the first
-- lesson_pdfs row). The app never writes it again.
--
-- ── Why NO unique(lesson_id, order_index) ──────────────────
-- The app reorders PDFs with one UPDATE per row via the Supabase client — each
-- is a separate transaction. A unique constraint (even DEFERRABLE INITIALLY
-- DEFERRED, which only defers to *that* transaction's commit) would collide
-- mid-sequence. Uniqueness is instead kept app-side by contiguous renumbering on
-- reorder (same approach as reorderLessons). A plain index is enough.
--
-- ── Why the mirror is a TRIGGER, not app code ──────────────
-- PDFs are saved via immediate per-row CRUD, not one atomic "save". Computing the
-- mirror in the Dart save handler would miss adds/deletes the admin never "saves"
-- and could leave pdf_url pointing at a deleted file. The trigger fires on every
-- insert/update/delete and stays correct (nulls out when the last PDF is gone).
-- SECURITY DEFINER lets the function UPDATE public.lessons even though the caller
-- (admin) has no direct grant path that RLS would otherwise satisfy; the WRITE
-- GATE stays the lesson_pdfs admin-write policy — a student is rejected there and
-- never reaches the trigger. search_path is pinned (injection hardening).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Child table (no unique constraint — plain index only)
-- ------------------------------------------------------------
create table if not exists public.lesson_pdfs (
  id          uuid primary key default uuid_generate_v4(),
  lesson_id   uuid not null references public.lessons(id) on delete cascade,
  title       text not null,
  url         text not null,
  order_index int  not null default 0,
  created_at  timestamptz not null default now()
);

comment on table public.lesson_pdfs is
  'ملفات PDF المتعددة لكل درس (النص، الكتاب، مرفقات). ترتيبها order_index.';

create index if not exists idx_lesson_pdfs_lesson
  on public.lesson_pdfs(lesson_id, order_index);

alter table public.lesson_pdfs enable row level security;

-- ------------------------------------------------------------
-- 2. RLS — mirror the lessons entitlement pattern.
--    SELECT: admin, or the parent lesson is published AND the caller is
--            entitled to it (can_read_lesson bypasses RLS internally → no
--            recursion, same mechanism as the lessons policy in 0007).
--    WRITE:  admin only (this is the security gate for the mirror trigger).
-- ------------------------------------------------------------
drop policy if exists "lesson_pdfs_select_entitled" on public.lesson_pdfs;
create policy "lesson_pdfs_select_entitled" on public.lesson_pdfs
for select using (
  public.is_admin()
  or exists (
    select 1 from public.lessons l
    where l.id = lesson_pdfs.lesson_id
      and l.status = 'published'
      and public.can_read_lesson(l.id, l.book_id)
  )
);

drop policy if exists "lesson_pdfs_admin_write" on public.lesson_pdfs;
create policy "lesson_pdfs_admin_write" on public.lesson_pdfs
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 3. Auto-mirror trigger: keep lessons.pdf_url = first lesson_pdfs row.
--    Runs AFTER every row change; nulls pdf_url when the last PDF is deleted.
--    SECURITY DEFINER (owner) so it can UPDATE public.lessons regardless of the
--    caller; the lesson_pdfs admin-write policy is the real gate.
-- ------------------------------------------------------------
create or replace function public.sync_lesson_pdf_url()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  -- Refresh the affected lesson(s). NEW/OLD lesson_id differ only if a PDF is
  -- ever re-parented; refresh both, skipping nulls and the duplicate.
  if (tg_op <> 'DELETE' and new.lesson_id is not null) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = new.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = new.lesson_id;
  end if;

  if (tg_op <> 'INSERT' and old.lesson_id is not null
      and old.lesson_id is distinct from
          (case when tg_op <> 'DELETE' then new.lesson_id end)) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = old.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = old.lesson_id;
  end if;

  return null; -- AFTER trigger: return value ignored
end;
$$;

drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
create trigger trg_sync_lesson_pdf_url
  after insert or update or delete on public.lesson_pdfs
  for each row execute function public.sync_lesson_pdf_url();

comment on column public.lessons.pdf_url is
  'DEPRECATED — auto-mirror of the first lesson_pdfs row (maintained by trigger '
  'sync_lesson_pdf_url), for legacy app builds only. Never written by the app.';

-- ------------------------------------------------------------
-- 4. Backfill: one PDF row per lesson that currently has a pdf_url.
--    (The trigger will re-affirm the same mirror value — harmless.)
-- ------------------------------------------------------------
insert into public.lesson_pdfs (lesson_id, title, url, order_index)
select id, 'ملف PDF', pdf_url, 0
from public.lessons
where pdf_url is not null
  and not exists (
    select 1 from public.lesson_pdfs p where p.lesson_id = public.lessons.id
  );

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
drop function if exists public.sync_lesson_pdf_url();
drop table if exists public.lesson_pdfs;   -- removes rows + policies
-- (lessons.pdf_url values remain as they were last mirrored)
*/

-- ============================================================
-- ✅ TEST HARNESS — run FIRST, verbatim, in the SQL Editor. Wrapped in a
-- transaction that ROLLS BACK, so nothing persists. Verifies:
--   (A) no 42P17 recursion when a real authenticated user selects lesson_pdfs;
--   (B) the SELECT policy hides other lessons' PDFs from a non-entitled user;
--   (C) SECURITY DEFINER lets the trigger update lessons.pdf_url, and the mirror
--       tracks insert / reorder / delete-last correctly;
--   (D) a NON-ADMIN authenticated user is REJECTED by the write policy and thus
--       can never fire the trigger (no privilege escalation via the mirror).
--
-- Replace <ADMIN_UUID>, <STUDENT_UUID>, <LESSON_UUID> (a published lesson) below.
-- ============================================================
/*
begin;

-- ---- (A)+(C) as ADMIN: writes allowed, trigger mirrors pdf_url --------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<ADMIN_UUID>","role":"authenticated","is_anonymous":false}';

-- insert two PDFs; after this, lessons.pdf_url should equal the order_index=0 url
insert into public.lesson_pdfs (lesson_id, title, url, order_index) values
  ('<LESSON_UUID>', 'الأول', 'https://drive.google.com/file/d/AAA/view', 0),
  ('<LESSON_UUID>', 'الثاني','https://drive.google.com/file/d/BBB/view', 1);
select pdf_url as after_insert_should_be_AAA
  from public.lessons where id = '<LESSON_UUID>';

-- reorder: make BBB first → mirror should become BBB
update public.lesson_pdfs set order_index = 0
  where lesson_id = '<LESSON_UUID>' and title = 'الثاني';
update public.lesson_pdfs set order_index = 1
  where lesson_id = '<LESSON_UUID>' and title = 'الأول';
select pdf_url as after_reorder_should_be_BBB
  from public.lessons where id = '<LESSON_UUID>';

-- delete all → mirror should become NULL
delete from public.lesson_pdfs where lesson_id = '<LESSON_UUID>';
select pdf_url as after_delete_should_be_null
  from public.lessons where id = '<LESSON_UUID>';

reset role;

-- ---- (D) as NON-ADMIN student: write MUST be rejected by RLS ----------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<STUDENT_UUID>","role":"authenticated","is_anonymous":false}';

-- Expected: ERROR new row violates row-level security policy for "lesson_pdfs".
-- (If this SUCCEEDS, the write gate is broken — do NOT ship.)
do $$
begin
  insert into public.lesson_pdfs (lesson_id, title, url, order_index)
  values ('<LESSON_UUID>', 'اختراق', 'https://x', 0);
  raise exception 'SECURITY FAIL: student insert into lesson_pdfs succeeded';
exception
  when insufficient_privilege or others then
    raise notice 'OK: student insert rejected (%).', sqlerrm;
end $$;

-- (A)+(B) student SELECT must not raise 42P17 and only sees entitled rows:
select count(*) as visible_pdf_rows from public.lesson_pdfs;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0012_lesson_pdfs.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0013_lesson_notes.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0013_lesson_notes.sql   (Student lecture notes)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: let a student attach a short plain-text note to a specific second of
-- a lecture video, and browse their notes per book. book_id is STORED (not just
-- derivable) so "all my notes in this book" is a single indexed query with no
-- join to lessons. Strictly owner-only (private notes).
-- ============================================================

create table if not exists public.lesson_notes (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id)   on delete cascade,
  lesson_id        uuid not null references public.lessons(id) on delete cascade,
  book_id          uuid not null references public.books(id)   on delete cascade,
  note_text        text not null check (char_length(btrim(note_text)) between 1 and 1000),
  position_seconds int  not null default 0 check (position_seconds >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.lesson_notes is
  'ملحوظات الطالب النصية المرتبطة بلحظة زمنية في فيديو المحاضرة.';

create index if not exists idx_lesson_notes_user_book
  on public.lesson_notes(user_id, book_id);
create index if not exists idx_lesson_notes_user_lesson
  on public.lesson_notes(user_id, lesson_id, position_seconds);

alter table public.lesson_notes enable row level security;

-- Table privileges (RLS narrows these row-by-row).
grant select, insert, update, delete on public.lesson_notes to authenticated;

-- RLS — strictly owner-only for every operation.
drop policy if exists "lesson_notes_select_own" on public.lesson_notes;
create policy "lesson_notes_select_own" on public.lesson_notes
  for select using (auth.uid() = user_id);

drop policy if exists "lesson_notes_insert_own" on public.lesson_notes;
create policy "lesson_notes_insert_own" on public.lesson_notes
  for insert with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_update_own" on public.lesson_notes;
create policy "lesson_notes_update_own" on public.lesson_notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_delete_own" on public.lesson_notes;
create policy "lesson_notes_delete_own" on public.lesson_notes
  for delete using (auth.uid() = user_id);

-- Auto-maintain updated_at (existing shared function).
drop trigger if exists trg_lesson_notes_updated_at on public.lesson_notes;
create trigger trg_lesson_notes_updated_at before update on public.lesson_notes
  for each row execute function public.set_updated_at();

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop table if exists public.lesson_notes;   -- removes rows, indexes, policies, trigger
*/

-- ============================================================
-- TEST HARNESS — run AFTER applying the migration above, as a SECOND query.
-- Wrapped in a transaction that ROLLS BACK, so nothing persists.
-- Verifies (as the AUTHENTICATED role, not postgres):
--   (A) an authenticated user can insert + select their OWN note;
--   (B) a SECOND authenticated user CANNOT see the first user's note (owner-only).
--
-- Replace <USER_A_UUID> and <USER_B_UUID> (two distinct real users) and
-- <LESSON_UUID> / <BOOK_UUID> (a lesson and its book) below.
-- Expected: after_insert = 1, then user B sees 0, then 'OK: owner-only verified'.
-- ============================================================
/*
begin;

-- ---- (A) as USER A: insert + select own note --------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_A_UUID>","role":"authenticated","is_anonymous":false}';

insert into public.lesson_notes (user_id, lesson_id, book_id, note_text, position_seconds)
values ('<USER_A_UUID>', '<LESSON_UUID>', '<BOOK_UUID>', 'ملحوظة تجريبية', 125);

select count(*) as after_insert_should_be_1
  from public.lesson_notes where user_id = '<USER_A_UUID>';

reset role;

-- ---- (B) as USER B: must NOT see USER A's note ------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_B_UUID>","role":"authenticated","is_anonymous":false}';

do $$
declare v int;
begin
  select count(*) into v from public.lesson_notes;
  if v <> 0 then
    raise exception 'SECURITY FAIL: user B can see % note(s) that are not theirs', v;
  end if;
  raise notice 'OK: owner-only verified (user B sees 0 notes).';
end $$;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0013_lesson_notes.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0014_quiz_entitlement.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0014_quiz_entitlement.sql  (Guest Mode, Stage 3)
-- Additive / hardening. Runs on top of 0001…0013 (+0002b, 0006b).
-- Run ONCE in Supabase SQL Editor.
--
-- Purpose: enforce lesson-quiz ENTITLEMENT server-side, closing the gap where a
-- registered-but-UNENROLLED user could fetch and submit any published lesson's
-- quiz directly (bypassing the UI gate). Today the data layer only excludes
-- guests (`not is_guest()`), not unenrolled users — same class of deep-link gap
-- already closed for the final exam.
--
-- ── Access model: STRICT ENROLLMENT ─────────────────────────
-- Quiz access requires an actual `enrollments` row for the lesson's book — even
-- the free first lesson requires enrollment for its QUIZ. Rationale: lesson 1 is
-- open so users can *sample content*, not be *assessed / accumulate progress*;
-- allowing an unenrolled submit would write lesson_quiz_attempts (and feed
-- achievements) for a user with no enrollment, corrupting the progress model; and
-- it matches the Stage-1 rule that guests are blocked from all quizzes, lesson 1
-- included. This is deliberately STRICTER than can_read_lesson (0007), which
-- grants lesson-1 CONTENT free — so we use a plain enrollments EXISTS here, the
-- same gate submit_final_exam already uses, NOT can_read_lesson.
--
-- ── No recursion (42P17) ────────────────────────────────────
-- This migration only recreates a VIEW and three SECURITY DEFINER FUNCTIONS — no
-- RLS policy is added or changed. The enrollment EXISTS subqueries `enrollments`,
-- never `lesson_quiz_questions` or the view itself, so policy self-recursion
-- cannot occur. The view is security_invoker = false (reads tables as owner,
-- RLS-bypassed), while auth.uid()/is_guest() still resolve from the caller's JWT.
--
-- A commented ROLLBACK block at the bottom restores the pre-0014 definitions
-- verbatim (0011 view + 0005 function bodies).
-- ============================================================

-- ------------------------------------------------------------
-- 1. View lesson_quiz_questions_student
--    Restates the 0011 definition (adds ai_review_status='approved' on top of
--    0005's `not is_guest()`), plus the new enrollment condition.
-- ------------------------------------------------------------
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
  and q.ai_review_status = 'approved'
  and exists (
    select 1 from public.enrollments e
    where e.book_id = l.book_id
      and e.user_id = auth.uid()
  );

-- Re-apply the existing grant (create or replace resets it).
grant select on public.lesson_quiz_questions_student to authenticated;

-- ------------------------------------------------------------
-- 2. submit_lesson_quiz — 0005 body verbatim + enrollment guard.
--    New: v_book_id declare; lesson→book lookup + enrollment EXISTS inserted
--    after the is_guest() guard, before the attempt count.
-- ------------------------------------------------------------
create or replace function public.submit_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id        uuid := auth.uid();
  v_book_id        uuid;
  v_attempt_count  int;
  v_attempt_number int;
  v_total          int;
  v_correct        int := 0;
  v_score_pct      int;
  v_passed         boolean;
  v_row            record;
  v_answer         text;
  v_max_attempts   constant int := 2;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  -- Entitlement (STRICT ENROLLMENT): the lesson's book must have an enrollment
  -- row for this user. Even the free first lesson requires enrollment for its quiz.
  select l.book_id into v_book_id
  from public.lessons l
  where l.id = p_lesson_id and l.status = 'published';

  if v_book_id is null then
    raise exception 'LESSON_NOT_FOUND' using errcode = 'P0005';
  end if;

  if not exists (
    select 1 from public.enrollments e
    where e.user_id = v_user_id and e.book_id = v_book_id
  ) then
    raise exception 'NOT_ENROLLED' using errcode = 'P0001';
  end if;

  select count(*) into v_attempt_count
  from public.lesson_quiz_attempts
  where user_id = v_user_id and lesson_id = p_lesson_id;

  if v_attempt_count >= v_max_attempts then
    raise exception 'attempts_exhausted';
  end if;

  v_attempt_number := v_attempt_count + 1;

  select count(*) into v_total
  from public.lesson_quiz_questions where lesson_id = p_lesson_id;

  for v_row in
    select id, correct_choice from public.lesson_quiz_questions
    where lesson_id = p_lesson_id
  loop
    v_answer := p_answers ->> (v_row.id::text);
    if v_answer is not null and v_answer = v_row.correct_choice then
      v_correct := v_correct + 1;
    end if;
  end loop;

  v_score_pct := case when v_total > 0
                      then round((v_correct::numeric / v_total) * 100)
                      else 0 end;
  v_passed    := v_score_pct >= 60;

  insert into public.lesson_quiz_attempts
    (user_id, lesson_id, attempt_number, score_percentage, passed, answers)
  values
    (v_user_id, p_lesson_id, v_attempt_number, v_score_pct, v_passed, p_answers);

  return jsonb_build_object(
    'correct',        v_correct,
    'total',          v_total,
    'percentage',     v_score_pct,
    'passed',         v_passed,
    'attempt_number', v_attempt_number,
    'attempts_used',  v_attempt_number
  );
end;
$$;
revoke all on function public.submit_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.submit_lesson_quiz(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 3. grade_lesson_quiz — 0005 body verbatim + enrollment guard.
--    Worst leak of the three: returns per-submission correctness with no attempt
--    limit, so an unenrolled user could brute-force correct answers. Same guard.
-- ------------------------------------------------------------
create or replace function public.grade_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
stable
as $$
declare
  v_book_id uuid;
  v_total   int;
  v_correct int := 0;
  v_row     record;
  v_answer  text;
begin
  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  -- Entitlement (STRICT ENROLLMENT) — same rule as submit_lesson_quiz.
  select l.book_id into v_book_id
  from public.lessons l
  where l.id = p_lesson_id and l.status = 'published';

  if v_book_id is null then
    raise exception 'LESSON_NOT_FOUND' using errcode = 'P0005';
  end if;

  if not exists (
    select 1 from public.enrollments e
    where e.user_id = auth.uid() and e.book_id = v_book_id
  ) then
    raise exception 'NOT_ENROLLED' using errcode = 'P0001';
  end if;

  select count(*) into v_total
  from public.lesson_quiz_questions
  where lesson_id = p_lesson_id;

  if v_total = 0 then
    return jsonb_build_object('correct', 0, 'total', 0, 'percentage', 0);
  end if;

  for v_row in
    select id, correct_choice
    from public.lesson_quiz_questions
    where lesson_id = p_lesson_id
  loop
    v_answer := p_answers ->> (v_row.id::text);
    if v_answer is not null and v_answer = v_row.correct_choice then
      v_correct := v_correct + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'correct',    v_correct,
    'total',      v_total,
    'percentage', round((v_correct::numeric / v_total) * 100)
  );
end;
$$;
revoke all on function public.grade_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.grade_lesson_quiz(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 4. get_lesson_quiz_review — 0005 body verbatim + enrollment guard.
--    Only ever returns the caller's OWN attempts (user_id = auth.uid()), so it is
--    not directly exploitable once submit is gated. The guard is defense-in-depth:
--    it also blocks reviewing any legacy attempt row created before this migration
--    by a user who has since had (or never had) an enrollment.
-- ------------------------------------------------------------
create or replace function public.get_lesson_quiz_review(
  p_lesson_id      uuid,
  p_attempt_number int default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id        uuid := auth.uid();
  v_book_id        uuid;
  v_answers        jsonb;
  v_attempt_number int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  -- Entitlement (STRICT ENROLLMENT) — same rule as submit_lesson_quiz.
  select l.book_id into v_book_id
  from public.lessons l
  where l.id = p_lesson_id and l.status = 'published';

  if v_book_id is null then
    raise exception 'LESSON_NOT_FOUND' using errcode = 'P0005';
  end if;

  if not exists (
    select 1 from public.enrollments e
    where e.user_id = v_user_id and e.book_id = v_book_id
  ) then
    raise exception 'NOT_ENROLLED' using errcode = 'P0001';
  end if;

  select attempt_number, answers
    into v_attempt_number, v_answers
    from public.lesson_quiz_attempts
   where user_id = v_user_id
     and lesson_id = p_lesson_id
     and (p_attempt_number is null or attempt_number = p_attempt_number)
   order by attempt_number desc
   limit 1;

  if not found then
    raise exception 'no_attempt_found';
  end if;

  return (
    select jsonb_build_object(
      'attempt_number', v_attempt_number,
      'questions', jsonb_agg(
        jsonb_build_object(
          'id',             q.id,
          'question_text',  q.question_text,
          'choice_a',       q.choice_a,
          'choice_b',       q.choice_b,
          'choice_c',       q.choice_c,
          'choice_d',       q.choice_d,
          'correct_choice', q.correct_choice,
          'user_answer',    v_answers ->> (q.id::text),
          'is_correct',     (v_answers ->> (q.id::text)) = q.correct_choice
        ) order by q.order_index
      )
    )
    from public.lesson_quiz_questions q
   where q.lesson_id = p_lesson_id
  );
end;
$$;
revoke all on function public.get_lesson_quiz_review(uuid, int) from public;
grant execute on function public.get_lesson_quiz_review(uuid, int) to authenticated;

-- ============================================================
-- ROLLBACK BLOCK — restores the pre-0014 definitions verbatim
-- (view from 0011_ai_question_generation.sql; the three function
-- bodies from 0005_guest_mode.sql). Uncomment and run to revert.
-- ============================================================
/*
-- View (0011): no enrollment condition.
create or replace view public.lesson_quiz_questions_student
  with (security_invoker = false)
as
select
  q.id, q.lesson_id, q.order_index, q.question_text,
  q.choice_a, q.choice_b, q.choice_c, q.choice_d, q.created_at
from public.lessons l
join public.lesson_quiz_questions q on q.lesson_id = l.id
where l.status = 'published'
  and not public.is_guest()
  and q.ai_review_status = 'approved';
grant select on public.lesson_quiz_questions_student to authenticated;

-- submit_lesson_quiz (0005): guest guard only, no enrollment check.
create or replace function public.submit_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id        uuid := auth.uid();
  v_attempt_count  int;
  v_attempt_number int;
  v_total          int;
  v_correct        int := 0;
  v_score_pct      int;
  v_passed         boolean;
  v_row            record;
  v_answer         text;
  v_max_attempts   constant int := 2;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  select count(*) into v_attempt_count
  from public.lesson_quiz_attempts
  where user_id = v_user_id and lesson_id = p_lesson_id;

  if v_attempt_count >= v_max_attempts then
    raise exception 'attempts_exhausted';
  end if;

  v_attempt_number := v_attempt_count + 1;

  select count(*) into v_total
  from public.lesson_quiz_questions where lesson_id = p_lesson_id;

  for v_row in
    select id, correct_choice from public.lesson_quiz_questions
    where lesson_id = p_lesson_id
  loop
    v_answer := p_answers ->> (v_row.id::text);
    if v_answer is not null and v_answer = v_row.correct_choice then
      v_correct := v_correct + 1;
    end if;
  end loop;

  v_score_pct := case when v_total > 0
                      then round((v_correct::numeric / v_total) * 100)
                      else 0 end;
  v_passed    := v_score_pct >= 60;

  insert into public.lesson_quiz_attempts
    (user_id, lesson_id, attempt_number, score_percentage, passed, answers)
  values
    (v_user_id, p_lesson_id, v_attempt_number, v_score_pct, v_passed, p_answers);

  return jsonb_build_object(
    'correct',        v_correct,
    'total',          v_total,
    'percentage',     v_score_pct,
    'passed',         v_passed,
    'attempt_number', v_attempt_number,
    'attempts_used',  v_attempt_number
  );
end;
$$;
revoke all on function public.submit_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.submit_lesson_quiz(uuid, jsonb) to authenticated;

-- grade_lesson_quiz (0005): guest guard only, no enrollment check.
create or replace function public.grade_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
stable
as $$
declare
  v_total   int;
  v_correct int := 0;
  v_row     record;
  v_answer  text;
begin
  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.lesson_quiz_questions
  where lesson_id = p_lesson_id;

  if v_total = 0 then
    return jsonb_build_object('correct', 0, 'total', 0, 'percentage', 0);
  end if;

  for v_row in
    select id, correct_choice
    from public.lesson_quiz_questions
    where lesson_id = p_lesson_id
  loop
    v_answer := p_answers ->> (v_row.id::text);
    if v_answer is not null and v_answer = v_row.correct_choice then
      v_correct := v_correct + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'correct',    v_correct,
    'total',      v_total,
    'percentage', round((v_correct::numeric / v_total) * 100)
  );
end;
$$;
revoke all on function public.grade_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.grade_lesson_quiz(uuid, jsonb) to authenticated;

-- get_lesson_quiz_review (0005): guest guard only, no enrollment check.
create or replace function public.get_lesson_quiz_review(
  p_lesson_id      uuid,
  p_attempt_number int default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id        uuid := auth.uid();
  v_answers        jsonb;
  v_attempt_number int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  select attempt_number, answers
    into v_attempt_number, v_answers
    from public.lesson_quiz_attempts
   where user_id = v_user_id
     and lesson_id = p_lesson_id
     and (p_attempt_number is null or attempt_number = p_attempt_number)
   order by attempt_number desc
   limit 1;

  if not found then
    raise exception 'no_attempt_found';
  end if;

  return (
    select jsonb_build_object(
      'attempt_number', v_attempt_number,
      'questions', jsonb_agg(
        jsonb_build_object(
          'id',             q.id,
          'question_text',  q.question_text,
          'choice_a',       q.choice_a,
          'choice_b',       q.choice_b,
          'choice_c',       q.choice_c,
          'choice_d',       q.choice_d,
          'correct_choice', q.correct_choice,
          'user_answer',    v_answers ->> (q.id::text),
          'is_correct',     (v_answers ->> (q.id::text)) = q.correct_choice
        ) order by q.order_index
      )
    )
    from public.lesson_quiz_questions q
   where q.lesson_id = p_lesson_id
  );
end;
$$;
revoke all on function public.get_lesson_quiz_review(uuid, int) from public;
grant execute on function public.get_lesson_quiz_review(uuid, int) to authenticated;
*/

-- ============================================================
-- End of migration 0014_quiz_entitlement.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0015_lesson_duration.sql
-- ============================================================
-- 0015_lesson_duration.sql
-- Additive migration: manual per-medium lesson durations + study-seconds RPC.
--
-- Study hours on the Achievements card were a flat 15-min-per-completed-lesson
-- estimate, which heavily under-counts long lessons. Durations are now entered
-- MANUALLY by the admin, separately for video and audio, in minutes. Students
-- never write to `lessons`. Study seconds are computed server-side from real
-- durations (completed lessons) and saved positions (in-progress lessons).

alter table public.lessons
  add column if not exists video_duration_minutes int null
    check (video_duration_minutes between 1 and 600),
  add column if not exists audio_duration_minutes int null
    check (audio_duration_minutes between 1 and 600);

comment on column public.lessons.video_duration_minutes is
  'مدة الفيديو بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';
comment on column public.lessons.audio_duration_minutes is
  'مدة الملف الصوتي بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';

-- ------------------------------------------------------------
-- get_my_study_seconds() — total study seconds for the current user.
-- SECURITY DEFINER so it can read lessons.*_duration_minutes regardless of the
-- caller's row-level access; scoped to auth.uid() so a user only ever sees own.
--
-- Per lesson_progress row (vp = video position, ap = audio position, both >= 0):
--   completed = true  → the primary medium's duration (the one with the larger
--                       saved position) in seconds, falling back to the other
--                       medium's duration, then to greatest(vp, ap) if non-zero,
--                       then to a 900s (15 min) constant.
--   completed = false → greatest(vp, ap), capped at the relevant medium's
--                       duration in seconds when that duration is known.
-- ------------------------------------------------------------
create or replace function public.get_my_study_seconds()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    case
      when lp.completed then
        coalesce(
          -- primary medium = the one the student engaged with more
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.audio_duration_minutes * 60
               else l.video_duration_minutes * 60
          end,
          -- fall back to the other medium's known duration
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.video_duration_minutes * 60
               else l.audio_duration_minutes * 60
          end,
          -- then to whatever position we managed to save
          nullif(greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)), 0),
          -- last-resort constant so completed lessons never count as zero
          900
        )
      else
        -- in-progress: real elapsed position, capped at the known duration.
        -- The cap uses the primary medium's duration (larger saved position),
        -- falling back to the other medium's duration — so an audio-only lesson
        -- still caps against audio when positions tie (video duration is null).
        case
          when coalesce(
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.audio_duration_minutes else l.video_duration_minutes end,
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.video_duration_minutes else l.audio_duration_minutes end
               ) is not null
          then least(
                 greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)),
                 coalesce(
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.audio_duration_minutes else l.video_duration_minutes end,
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.video_duration_minutes else l.audio_duration_minutes end
                 ) * 60)
          else greatest(coalesce(lp.video_position_seconds, 0),
                        coalesce(lp.audio_position_seconds, 0))
        end
    end
  ), 0)::bigint
  from public.lesson_progress lp
  join public.lessons l on l.id = lp.lesson_id
  where lp.user_id = auth.uid();
$$;

grant execute on function public.get_my_study_seconds() to authenticated;

-- ============================================================
-- SOURCE: supabase/migrations/0016_lessons_public_duration.sql
-- ============================================================
-- 0016_lessons_public_duration.sql
-- Additive: expose the admin-entered per-medium durations (migration 0015) to
-- the student-facing lesson list, which reads the URL-free `lessons_public`
-- view (0006 → 0008). Both columns are plain metadata (minutes, nullable) — no
-- URLs or quiz content — so surfacing them keeps the view's guest-safe contract.
--
-- Full `create or replace view` that re-states 0008's definition and appends
-- video_duration_minutes / audio_duration_minutes. security_invoker = false is
-- preserved so the view keeps running as owner (unchanged behaviour).

create or replace view public.lessons_public
  with (security_invoker = false)
as
select
  id,
  book_id,
  order_index,
  title,
  description,
  audio_only,
  status,
  created_at,
  updated_at,
  (video_url is not null and not audio_only) as has_video,
  (audio_url is not null)                    as has_audio,
  (pdf_url is not null)                      as has_pdf,
  -- Presence only — true iff the lesson has at least one quiz question.
  (exists (
     select 1 from public.lesson_quiz_questions q
     where q.lesson_id = lessons.id
   ))                                        as has_quiz,
  video_duration_minutes,
  audio_duration_minutes
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;

