-- ============================================================
-- Test harness for 0014_quiz_entitlement.sql
-- Run ENTIRELY in the Supabase SQL Editor. SELF-APPLYING (0007-style):
-- it applies the four new definitions inside its own transaction, exercises
-- them AS the `authenticated` role (never postgres — the editor's own role
-- bypasses RLS and would hide the bug), then ROLLS BACK so nothing persists —
-- neither the new defs nor the test rows. Run this FIRST; apply the migration
-- file only after all three personas pass.
--
-- Requirements (real data — no placeholder UUIDs, they'd fail the FK):
--   • ≥1 non-guest user enrolled in a book that has a published lesson with ≥1
--     approved quiz question, where that user has < 2 attempts on that lesson.
--   • ≥1 other non-guest user NOT enrolled in that same book.
-- If either is missing, the block raises a clear SETUP ERROR.
--
-- Expected: three personas —
--   1. enrolled            → sees quiz rows,   submit accepted (total > 0)
--   2. registered/unenrolled → zero rows,       submit + grade rejected (P0001)
--   3. guest               → zero rows,         submit rejected (42501)
-- ============================================================

begin;

-- ── Apply the 0014 definitions inside this transaction ──────────────────────

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
  and q.ai_review_status = 'approved'
  and exists (
    select 1 from public.enrollments e
    where e.book_id = l.book_id
      and e.user_id = auth.uid()
  );
grant select on public.lesson_quiz_questions_student to authenticated;

create or replace function public.submit_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
as $fn$
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
$fn$;
revoke all on function public.submit_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.submit_lesson_quiz(uuid, jsonb) to authenticated;

create or replace function public.grade_lesson_quiz(
  p_lesson_id  uuid,
  p_answers    jsonb
)
returns jsonb
language plpgsql
security definer
stable
as $fn$
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
$fn$;
revoke all on function public.grade_lesson_quiz(uuid, jsonb) from public;
grant execute on function public.grade_lesson_quiz(uuid, jsonb) to authenticated;

create or replace function public.get_lesson_quiz_review(
  p_lesson_id      uuid,
  p_attempt_number int default null
)
returns jsonb
language plpgsql
security definer
as $fn$
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
$fn$;
revoke all on function public.get_lesson_quiz_review(uuid, int) from public;
grant execute on function public.get_lesson_quiz_review(uuid, int) to authenticated;

-- ── Exercise the three personas ─────────────────────────────────────────────
do $$
declare
  v_enrolled_user    uuid;
  v_book             uuid;
  v_lesson           uuid;
  v_unenrolled_user  uuid;
  v_answers          jsonb;
  v_result           jsonb;
  v_cnt              int;
  v_state            text;
begin

  -- ── Fixture discovery (as owner — RLS bypassed) ───────────────────────────
  -- An enrolled non-guest user + a published lesson of their book with an
  -- approved quiz question, where the user still has attempts left (< 2) so the
  -- positive submit test isn't blocked by attempts_exhausted.
  select e.user_id, e.book_id, l.id
    into v_enrolled_user, v_book, v_lesson
  from public.enrollments e
  join public.users u
    on u.id = e.user_id and u.email not like '%@guest.sheikhy.local'
  join public.lessons l
    on l.book_id = e.book_id and l.status = 'published'
  where exists (
          select 1 from public.lesson_quiz_questions q
          where q.lesson_id = l.id and q.ai_review_status = 'approved'
        )
    and (
          select count(*) from public.lesson_quiz_attempts a
          where a.user_id = e.user_id and a.lesson_id = l.id
        ) < 2
  limit 1;

  if v_enrolled_user is null then
    raise exception
      'SETUP ERROR: need a non-guest user enrolled in a book that has a published '
      'lesson with an approved quiz question, and fewer than 2 existing attempts on '
      'that lesson. None found — enroll a student and add/approve a quiz question.';
  end if;

  -- A different non-guest user NOT enrolled in that book.
  select u.id
    into v_unenrolled_user
  from public.users u
  where u.email not like '%@guest.sheikhy.local'
    and u.id <> v_enrolled_user
    and not exists (
          select 1 from public.enrollments e
          where e.user_id = u.id and e.book_id = v_book
        )
  limit 1;

  if v_unenrolled_user is null then
    raise exception
      'SETUP ERROR: need a second non-guest user NOT enrolled in book %. '
      'Sign up another student (do not enroll them in this book).', v_book;
  end if;

  -- Arbitrary answer set over the approved questions of the test lesson.
  select jsonb_object_agg(q.id::text, 'a')
    into v_answers
  from public.lesson_quiz_questions q
  where q.lesson_id = v_lesson and q.ai_review_status = 'approved';

  raise notice 'Fixtures — enrolled: %, book: %, lesson: %, unenrolled: %',
    v_enrolled_user, v_book, v_lesson, v_unenrolled_user;

  -- ── PERSONA 1: enrolled ───────────────────────────────────────────────────
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_enrolled_user, 'role', 'authenticated',
                      'is_anonymous', false)::text,
    true
  );
  set local role authenticated;

  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where lesson_id = v_lesson;
  assert v_cnt > 0,
    format('TEST 1a FAIL: enrolled user should see quiz rows, got %s', v_cnt);
  raise notice 'TEST 1a PASS: enrolled user sees % quiz row(s)', v_cnt;

  v_result := public.submit_lesson_quiz(v_lesson, v_answers);
  assert (v_result ->> 'total')::int > 0,
    format('TEST 1b FAIL: enrolled submit returned total=%s', v_result ->> 'total');
  raise notice 'TEST 1b PASS: enrolled user submit accepted (total=%)',
    v_result ->> 'total';

  reset role;

  -- ── PERSONA 2: registered / unenrolled ────────────────────────────────────
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_unenrolled_user, 'role', 'authenticated',
                      'is_anonymous', false)::text,
    true
  );
  set local role authenticated;

  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where lesson_id = v_lesson;
  assert v_cnt = 0,
    format('TEST 2a FAIL: unenrolled user must see 0 quiz rows, got %s', v_cnt);
  raise notice 'TEST 2a PASS: unenrolled user sees zero quiz rows';

  v_state := null;
  begin
    perform public.submit_lesson_quiz(v_lesson, v_answers);
  exception when others then
    v_state := sqlstate;
  end;
  assert v_state = 'P0001',
    format('TEST 2b FAIL: unenrolled submit expected P0001 (NOT_ENROLLED), got %s',
           coalesce(v_state, '<no error raised>'));
  raise notice 'TEST 2b PASS: unenrolled submit rejected (P0001 NOT_ENROLLED)';

  v_state := null;
  begin
    perform public.grade_lesson_quiz(v_lesson, v_answers);
  exception when others then
    v_state := sqlstate;
  end;
  assert v_state = 'P0001',
    format('TEST 2c FAIL: unenrolled grade expected P0001 (NOT_ENROLLED), got %s',
           coalesce(v_state, '<no error raised>'));
  raise notice 'TEST 2c PASS: unenrolled grade rejected (P0001 NOT_ENROLLED)';

  reset role;

  -- ── PERSONA 3: guest (is_anonymous = true; enrolled sub proves guest guard
  --    fires BEFORE the enrollment check) ──────────────────────────────────
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_enrolled_user, 'role', 'authenticated',
                      'is_anonymous', true)::text,
    true
  );
  set local role authenticated;

  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where lesson_id = v_lesson;
  assert v_cnt = 0,
    format('TEST 3a FAIL: guest must see 0 quiz rows, got %s', v_cnt);
  raise notice 'TEST 3a PASS: guest sees zero quiz rows';

  v_state := null;
  begin
    perform public.submit_lesson_quiz(v_lesson, v_answers);
  exception when others then
    v_state := sqlstate;
  end;
  assert v_state = '42501',
    format('TEST 3b FAIL: guest submit expected 42501 (GUESTS_NOT_ALLOWED), got %s',
           coalesce(v_state, '<no error raised>'));
  raise notice 'TEST 3b PASS: guest submit rejected (42501 GUESTS_NOT_ALLOWED)';

  reset role;

  raise notice '─────────────────────────────────────────';
  raise notice 'All personas passed. Rolling back (defs + test rows discarded).';
end $$;

rollback;
-- ============================================================
-- End of 0014_quiz_entitlement_test.sql
-- ============================================================
