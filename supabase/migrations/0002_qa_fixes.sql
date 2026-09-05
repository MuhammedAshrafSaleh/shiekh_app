-- Migration 0002: Fix Q&A student view + nullable lesson_id
--
-- Problem 1: student_questions_public was created with security_invoker = true,
-- but the companion migration dropped the student SELECT policy on the base table.
-- Students received 0 rows (PostgREST silently returns [] when RLS blocks all rows).
-- Fix: recreate view without security_invoker so it runs as the view owner (security_definer
-- behavior), bypassing RLS. The WHERE clause remains the security boundary.
--
-- Problem 2: lesson_id was NOT NULL, preventing book-level (general) questions.
-- Fix: make it nullable; FK constraint is kept; null means no lesson context.

-- 1. Recreate the view without security_invoker
create or replace view public.student_questions_public
as
select
  q.id,
  q.book_id,
  q.lesson_id,
  q.question_text,
  q.answer_text,
  q.status,
  q.answered_at,
  q.created_at
from public.student_questions q
left join public.lessons l on l.id = q.lesson_id
where q.lesson_id is null or l.status = 'published';

grant select on public.student_questions_public to authenticated;

-- 2. Make lesson_id nullable
alter table public.student_questions
  alter column lesson_id drop not null;
