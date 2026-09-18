-- ============================================================
-- Test harness for 0011_ai_question_generation.sql
-- Run AFTER applying 0011, entirely in Supabase SQL Editor.
-- Everything is wrapped in BEGIN … ROLLBACK so no test rows
-- are ever committed.
--
-- Requirements:
--   • Migration 0011 already applied.
--   • At least one published lesson in the DB.
--   • At least one real (non-guest) user in public.users.
-- ============================================================

begin;

do $$
declare
  v_user_id     uuid;
  v_lesson_id   uuid;
  v_book_id     uuid;
  v_q_pending   uuid := gen_random_uuid();
  v_q_approved  uuid := gen_random_uuid();
  v_q_pre       uuid;   -- a pre-migration row (no explicit status set)
  v_job_id      uuid := gen_random_uuid();
  v_ts_before   timestamptz;
  v_ts_after    timestamptz;
  v_cnt         int;
begin

  -- ── Pick a real authenticated user ─────────────────────────
  select id into v_user_id
  from public.users
  where email not like '%@guest.sheikhy.local'
  order by created_at
  limit 1;

  if v_user_id is null then
    raise exception
      'SETUP ERROR: no real users in public.users. '
      'Sign up at least one student account first.';
  end if;

  raise notice 'Using user: %', v_user_id;

  -- ── Pick a published lesson ─────────────────────────────────
  select l.id, l.book_id into v_lesson_id, v_book_id
  from public.lessons l
  where l.status = 'published'
  order by l.created_at
  limit 1;

  if v_lesson_id is null then
    raise exception
      'SETUP ERROR: no published lessons found. '
      'Publish at least one lesson before running this harness.';
  end if;

  raise notice 'Using lesson: %', v_lesson_id;

  -- ── Seed test quiz-question rows (as postgres, bypasses RLS) ─
  -- Row 1: ai_review_status = 'pending' — must NOT appear in student view
  insert into public.lesson_quiz_questions
    (id, lesson_id, order_index, question_text,
     choice_a, choice_b, choice_c, choice_d,
     correct_choice, source, ai_review_status)
  values
    (v_q_pending, v_lesson_id, 9901, 'سؤال اختبار 0011 — معلق',
     'أ', 'ب', 'ج', 'د', 'a', 'ai_generated', 'pending');

  -- Row 2: ai_review_status = 'approved' — MUST appear in student view
  insert into public.lesson_quiz_questions
    (id, lesson_id, order_index, question_text,
     choice_a, choice_b, choice_c, choice_d,
     correct_choice, source, ai_review_status)
  values
    (v_q_approved, v_lesson_id, 9902, 'سؤال اختبار 0011 — معتمد',
     'أ', 'ب', 'ج', 'د', 'b', 'ai_generated', 'approved');

  -- Row 3: pre-migration simulation — insert with no explicit ai_review_status
  -- (column default = 'approved') to prove old rows are unaffected.
  insert into public.lesson_quiz_questions
    (lesson_id, order_index, question_text,
     choice_a, choice_b, choice_c, choice_d, correct_choice)
  values
    (v_lesson_id, 9903, 'سؤال اختبار 0011 — قديم بدون حالة مراجعة',
     'أ', 'ب', 'ج', 'د', 'c')
  returning id into v_q_pre;

  raise notice 'Seeded: pending=%, approved=%, pre-migration=%',
    v_q_pending, v_q_approved, v_q_pre;

  -- ── Switch to authenticated role (simulates a student) ───────
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',          v_user_id,
      'role',         'authenticated',
      'is_anonymous', false
    )::text,
    true
  );
  set local role authenticated;

  -- ── TEST a: pending row is hidden from student view ──────────
  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where id = v_q_pending;

  assert v_cnt = 0,
    format('TEST a FAIL: pending question must not appear in student view, got %s', v_cnt);
  raise notice 'TEST a PASS: pending question is hidden from students';

  -- ── TEST b: approved row appears in student view ─────────────
  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where id = v_q_approved;

  assert v_cnt = 1,
    format('TEST b FAIL: approved question must appear in student view, got %s', v_cnt);
  raise notice 'TEST b PASS: approved question is visible to students';

  -- ── TEST c: pre-migration row (default='approved') appears ───
  select count(*) into v_cnt
  from public.lesson_quiz_questions_student
  where id = v_q_pre;

  assert v_cnt = 1,
    format('TEST c FAIL: pre-migration row (default approved) must appear, got %s', v_cnt);
  raise notice 'TEST c PASS: pre-migration row (no explicit status) is visible — zero regression';

  -- ── TEST d: updated_at auto-stamps on generation_jobs update ─
  -- now() is transaction-scoped so pg_sleep cannot make it advance.
  -- Instead: seed the row with a known-stale updated_at via INSERT
  -- (BEFORE UPDATE trigger does not fire on INSERT), then do the real
  -- status update and assert the trigger overwrote the stale value.
  reset role;
  insert into public.generation_jobs
    (id, lesson_id, job_type, status, created_by, updated_at)
  values
    (v_job_id, v_lesson_id, 'transcribe', 'queued', v_user_id,
     now() - interval '1 hour');

  select updated_at into v_ts_before
  from public.generation_jobs where id = v_job_id;

  -- This UPDATE fires the trigger, which stamps updated_at = now().
  -- now() (transaction start) is always > now() - 1 hour.
  update public.generation_jobs
  set status = 'running'
  where id = v_job_id;

  select updated_at into v_ts_after
  from public.generation_jobs where id = v_job_id;

  assert v_ts_after > v_ts_before,
    format('TEST d FAIL: trigger did not overwrite stale updated_at (stale=%s, after=%s)',
           v_ts_before, v_ts_after);
  raise notice 'TEST d PASS: trigger overwrote stale updated_at (stale=%, after=%)',
    v_ts_before, v_ts_after;

  raise notice '─────────────────────────────────────────';
  raise notice 'All 4 tests passed. Rolling back test data.';

end $$;

rollback;
-- ============================================================
-- End of 0011_ai_question_generation_test.sql
-- ============================================================
