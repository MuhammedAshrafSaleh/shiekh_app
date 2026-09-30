-- 0019_bank_lesson_summaries.sql
--
-- Supports the question-bank import drill-down (admin). Additive and safe to
-- re-run: `add column if not exists`, `create or replace`, idempotent grant.

-- 1. Lesson-quiz provenance link (mirrors final_exam_questions.source_quiz_question_id).
--    Enables "already added" marking on lesson-quiz imports AND keeps imported
--    copies out of the bank. Existing rows stay NULL (no backfill).
alter table public.lesson_quiz_questions
  add column if not exists source_question_id uuid
  references public.lesson_quiz_questions(id) on delete set null;

-- 2. Per-lesson approved-question summary for the import drill-down (Step 1).
--    Bank = originals only: approved AND not itself an imported copy.
create or replace function public.bank_lesson_summaries(p_book_id uuid)
returns table (lesson_id uuid, title text, order_index int, approved_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  return query
    select l.id, l.title, l.order_index, count(q.id)
    from public.lessons l
    join public.lesson_quiz_questions q
      on q.lesson_id = l.id
     and q.ai_review_status = 'approved'
     and q.source_question_id is null   -- originals only; exclude imported copies
    where l.book_id = p_book_id
    group by l.id, l.title, l.order_index
    having count(q.id) > 0
    order by l.order_index;
end; $$;

grant execute on function public.bank_lesson_summaries(uuid) to authenticated;
