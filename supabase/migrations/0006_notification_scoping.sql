-- ============================================================
-- Sheikhy — Migration 0006_notification_scoping.sql
-- Runs on top of 0001 → 0005.
--
-- Problem: the notifications table has no per-user targeting column,
-- so the SELECT policy "using (true)" broadcasts every row to every
-- authenticated user. The submit_final_exam RPC inserts personal
-- achievement notifications into this table; those rows should be
-- visible only to the student who earned the certificate — not to
-- every other student in the app.
--
-- Fix:
--   1. Add nullable target_user_id column.
--      NULL  = admin broadcast (everyone sees it — existing behaviour).
--      non-NULL = personal (only auth.uid() = target_user_id sees it).
--   2. Replace "using (true)" SELECT policy with a scoped one.
--   3. Recreate submit_final_exam to set target_user_id on
--      achievement inserts (only change vs. 0005 body).
-- ============================================================

-- ============================================================
-- SECTION 1: Add target_user_id column
-- ============================================================
alter table public.notifications
  add column if not exists target_user_id uuid
    references public.users(id) on delete cascade;

comment on column public.notifications.target_user_id is
  'NULL = broadcast to all students; non-NULL = personal notification visible only to this user';

-- ============================================================
-- SECTION 2: Replace the open SELECT policy with a scoped one
-- No subquery over the same table — auth.uid() only — zero
-- risk of the recursive-policy crash (SQLSTATE 42P17).
-- ============================================================
drop policy if exists "notifications_select_all" on public.notifications;

create policy "notifications_select_scoped" on public.notifications
  for select using (
    target_user_id is null            -- admin broadcast: visible to all
    or target_user_id = auth.uid()    -- personal: only the target student
  );

-- ============================================================
-- SECTION 3: Recreate submit_final_exam with target_user_id
-- Body is verbatim from 0005_guest_mode.sql; the only change is
-- the achievement INSERT now includes target_user_id = v_user_id.
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

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
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
      -- target_user_id scopes this to the earning student only (0006 change)
      insert into public.notifications (
        type, title, body, created_by, target_user_id
      ) values (
        'achievement',
        'تهانيّ! لقد حصلت على شهادة',
        format(
          'أكملت الاختبار الشامل بدرجة %s%% (%s). شهادتك جاهزة للتحميل.',
          v_score_pct,
          v_grade_label
        ),
        v_user_id,
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

-- ============================================================
-- ROLLBACK BLOCK — uncomment and run to restore pre-0006 behaviour
-- ============================================================
/*
alter table public.notifications drop column if exists target_user_id;

drop policy if exists "notifications_select_scoped" on public.notifications;
create policy "notifications_select_all" on public.notifications
  for select using (true);

-- Revert submit_final_exam to the 0005 body (achievement INSERT without target_user_id)
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
  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
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
*/

-- ============================================================
-- End of migration 0006_notification_scoping.sql
-- ============================================================
