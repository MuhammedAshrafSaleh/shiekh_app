
-- 3a. Lesson quiz questions WITHOUT correct_choice (CC-18)
-- security_invoker = false: view runs as owner so it can read the admin-only
-- base table; the view itself is the security boundary (no correct_choice).
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
where l.status = 'published';

-- Policy: any authenticated user can read this view
-- (RLS on base table already blocks correct_choice)
grant select on public.lesson_quiz_questions_student to authenticated;

-- 3b. Final exam questions WITHOUT correct_choice (CC-18)
-- security_invoker = false: same reason as above.
create or replace view public.final_exam_questions_student
  with (security_invoker = false)
as
select
  q.id,
  q.book_id,
  q.order_index,
  q.question_text,
  q.choice_a,
  q.choice_b,
  q.choice_c,
  q.choice_d,
  q.created_at
from public.final_exam_questions q
join public.final_exam_settings s on s.book_id = q.book_id
where s.is_published = true;

grant select on public.final_exam_questions_student to authenticated;

-- 3c. Student questions WITHOUT user_id (CC-22)
--     Answered questions only; pending are visible too (peer learning)