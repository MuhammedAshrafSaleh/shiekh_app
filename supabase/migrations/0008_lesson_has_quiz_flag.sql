-- ============================================================
-- Sheikhy — Migration 0008_lesson_has_quiz_flag.sql  (Guest Mode, Stage 2)
--
-- 🚫 PROPOSED — DO NOT RUN until reviewed + verified with the TEST HARNESS at
--    the bottom (run in a transaction that is ROLLED BACK, as the `authenticated`
--    role — testing as postgres proves nothing about RLS/entitlement).
--
-- Purpose: give the client an entitlement-INDEPENDENT "this lesson has a quiz"
-- signal, so the quiz tab can stay VISIBLE (but gated) for guests / unenrolled
-- users on lessons that actually have a quiz, while lessons with no quiz keep
-- hiding the tab.
--
-- Why this is safe: `lessons_public` is a view with security_invoker = false, so
-- it runs as the owner and bypasses RLS on lesson_quiz_questions. The new column
-- exposes ONLY a boolean (presence) — never any question content. Guests still
-- fetch 0 rows from lesson_quiz_questions_student; that is unchanged. This is a
-- view (not an RLS policy), so the 0006-class recursion cannot occur.
--
-- This is a full `create or replace view` that re-states 0006's definition and
-- appends `has_quiz` at the end.
-- ============================================================

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
   ))                                        as has_quiz
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;

-- ============================================================
-- Find test lesson ids to plug into the harness:
--   -- a lesson WITH a quiz:
--   select l.id from public.lessons l
--   where l.status='published'
--     and exists (select 1 from public.lesson_quiz_questions q where q.lesson_id=l.id)
--   limit 1;
--   -- a lesson WITHOUT a quiz:
--   select l.id from public.lessons l
--   where l.status='published'
--     and not exists (select 1 from public.lesson_quiz_questions q where q.lesson_id=l.id)
--   limit 1;
-- ============================================================

-- ============================================================
-- ✅ TEST HARNESS — run FIRST, verbatim. Applies the view change, reads it AS a
-- real authenticated user AND as a guest, confirms has_quiz is correct and that
-- guests STILL get 0 quiz rows, then ROLLS BACK (nothing persists).
-- Replace <QUIZ_LESSON>, <NO_QUIZ_LESSON>, <REAL_USER_UUID>.
-- ============================================================
/*
begin;

create or replace view public.lessons_public with (security_invoker = false) as
select id, book_id, order_index, title, description, audio_only, status,
       created_at, updated_at,
       (video_url is not null and not audio_only) as has_video,
       (audio_url is not null)                    as has_audio,
       (pdf_url is not null)                      as has_pdf,
       (exists (select 1 from public.lesson_quiz_questions q
                where q.lesson_id = lessons.id))  as has_quiz
from public.lessons where status = 'published';
grant select on public.lessons_public to authenticated;

-- (a) as a registered user:
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<REAL_USER_UUID>","role":"authenticated","is_anonymous":false}';
select id, has_quiz from public.lessons_public
where id in ('<QUIZ_LESSON>', '<NO_QUIZ_LESSON>');   -- expect true, false
reset role;

-- (b) as a guest — has_quiz must be the SAME booleans, and quiz CONTENT still 0:
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<REAL_USER_UUID>","role":"authenticated","is_anonymous":true}';
select id, has_quiz from public.lessons_public
where id in ('<QUIZ_LESSON>', '<NO_QUIZ_LESSON>');   -- expect true, false
select count(*) as guest_quiz_rows
from public.lesson_quiz_questions_student where lesson_id = '<QUIZ_LESSON>';  -- expect 0
reset role;

rollback;
*/
-- ============================================================
-- End of migration 0008_lesson_has_quiz_flag.sql
-- ============================================================
