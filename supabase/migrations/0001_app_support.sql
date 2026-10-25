-- ============================================================
-- Sheikhy — Migration 0001_app_support.sql
-- Student-safe views + assessment RPCs (original pre-guest state)
--
-- RECOVERY NOTE (2026-10-25): This file was partially truncated
-- in the recovery audit (commit 022f2f8). Sections 1–2 (the 5
-- assessment RPCs) and the tail of section 3c were missing.
-- Restored from the verbatim rollback block in 0005_guest_mode.sql
-- which explicitly preserves "the 5 RPCs … unchanged" from 0001.
-- On a fresh install the sequence 0001 → 0005 is idempotent:
--   0001 creates the pre-guest versions; 0005 replaces them with
--   is_guest() guards; 0014 adds enrollment enforcement.
-- ============================================================

-- ============================================================
-- SECTION 1: grade_lesson_quiz
-- Admin / preview grader — does not persist an attempt.
-- Superseded (guest guard added) by 0005_guest_mode.sql.
-- ============================================================
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

-- ============================================================
-- SECTION 2: submit_final_exam, submit_lesson_quiz,
--            get_lesson_quiz_review, get_final_exam_review
-- All SECURITY DEFINER; grading, attempt counting, and
-- certificate issuance are entirely server-side.
-- Superseded by 0005 (guest guards) and 0006 (target_user_id
-- in the notification insert inside submit_final_exam).
-- ============================================================

create or replace function public.submit_final_exam(
  p_book_id    uuid,
  p_answers    jsonb,
  p_started_at timestamptz
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id        uuid := auth.uid();
  v_settings       record;
  v_attempt_count  int;
  v_attempt_number int;
  v_total_q        int;
  v_correct        int := 0;
  v_score_pct      int;
  v_passed         boolean;
  v_grade_label    text;
  v_attempt_id     uuid;
  v_cert_issued    bigint := 0;
  v_row            record;
  v_answer         text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.enrollments
    where user_id = v_user_id and book_id = p_book_id
  ) then
    raise exception 'NOT_ENROLLED' using errcode = 'P0001';
  end if;

  select * into v_settings
  from public.final_exam_settings
  where book_id = p_book_id and is_published = true;

  if not found then
    raise exception 'EXAM_NOT_PUBLISHED' using errcode = 'P0002';
  end if;

  select count(*), coalesce(max(attempt_number), 0)
  into v_attempt_count, v_attempt_number
  from public.final_exam_attempts
  where user_id = v_user_id and book_id = p_book_id;

  if v_attempt_count >= v_settings.max_attempts then
    raise exception 'ATTEMPTS_EXHAUSTED' using errcode = 'P0003';
  end if;

  select count(*) into v_total_q
  from public.final_exam_questions
  where book_id = p_book_id;

  if v_total_q = 0 then
    raise exception 'NO_QUESTIONS' using errcode = 'P0004';
  end if;

  for v_row in
    select id, correct_choice
    from public.final_exam_questions
    where book_id = p_book_id
  loop
    v_answer := p_answers ->> (v_row.id::text);
    if v_answer is not null and v_answer = v_row.correct_choice then
      v_correct := v_correct + 1;
    end if;
  end loop;

  v_score_pct := round((v_correct::numeric / v_total_q) * 100);
  v_passed := v_score_pct >= v_settings.passing_percentage;

  v_grade_label := case
    when v_score_pct >= 90 then 'ممتاز'
    when v_score_pct >= 80 then 'جيد جداً'
    else 'جيد'
  end;

  insert into public.final_exam_attempts (
    user_id, book_id, attempt_number, score_percentage,
    passed, answers, started_at, submitted_at
  ) values (
    v_user_id, p_book_id, v_attempt_number + 1, v_score_pct,
    v_passed, p_answers, p_started_at, now()
  )
  returning id into v_attempt_id;

  if v_passed then
    insert into public.certificates (
      user_id, book_id, final_exam_attempt_id,
      final_score, grade_label, issued_at
    ) values (
      v_user_id, p_book_id, v_attempt_id,
      v_score_pct, v_grade_label, now()
    )
    on conflict (user_id, book_id) do nothing;

    get diagnostics v_cert_issued = ROW_COUNT;

    if v_cert_issued > 0 then
      insert into public.notifications (
        type, title, body, created_by
      ) values (
        'achievement',
        'تهانيّ! لقد حصلت على شهادة',
        format(
          'أكملت الاختبار الشامل بدرجة %s%% (%s). شهادتك جاهزة للتحميل.',
          v_score_pct,
          v_grade_label
        ),
        v_user_id
      );
    end if;
  end if;

  return jsonb_build_object(
    'attempt_id',    v_attempt_id,
    'score',         v_score_pct,
    'correct',       v_correct,
    'total',         v_total_q,
    'passed',        v_passed,
    'grade_label',   v_grade_label,
    'cert_issued',   (v_cert_issued > 0)
  );
end;
$$;
revoke all on function public.submit_final_exam(uuid, jsonb, timestamptz) from public;
grant execute on function public.submit_final_exam(uuid, jsonb, timestamptz) to authenticated;

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

create or replace function public.get_final_exam_review(
  p_book_id    uuid,
  p_attempt_id uuid
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id  uuid := auth.uid();
  v_answers  jsonb;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select answers into v_answers
  from public.final_exam_attempts
  where id = p_attempt_id and user_id = v_user_id and book_id = p_book_id;

  if not found then
    raise exception 'no_attempt_found';
  end if;

  return (
    select jsonb_agg(
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
    from public.final_exam_questions q
    where q.book_id = p_book_id
  );
end;
$$;
revoke all on function public.get_final_exam_review(uuid, uuid) from public;
grant execute on function public.get_final_exam_review(uuid, uuid) to authenticated;

-- ============================================================
-- SECTION 3: Student-safe views (CC-18, CC-22)
-- 3a and 3b omit correct_choice so the client never receives
-- answers before grading. 3c omits user_id for Q&A anonymity.
-- All three are superseded by 0005 (is_guest() added) and
-- 3a is further updated by 0011 (AI columns) and 0014
-- (enrollment enforcement).
-- ============================================================

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
--     All questions shown for peer learning; answered + pending both visible.
--     lesson_id may be null (book-level questions) — handled by LEFT JOIN.
--     Fixed in 0002_qa_fixes: security_invoker removed, lesson_id made nullable.
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
