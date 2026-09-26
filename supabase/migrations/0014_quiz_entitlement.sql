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
