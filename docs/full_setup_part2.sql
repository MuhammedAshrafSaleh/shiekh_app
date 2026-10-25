-- ============================================================
-- docs/full_setup_part2.sql — Sheikhy setup, Part 2 of 4
-- ============================================================
-- Migrations 0005–0008  (guest mode + entitlement)
-- Run the four parts in order (part1 → part2 → part3 → part4);
-- each part assumes every earlier part already succeeded.
--
-- [!] Elevated-privilege statements (postgres role; fine in the
--     Supabase SQL Editor):
--       • (none in this part)
-- Generated: 2026-10-25
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0005_guest_mode.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0005_guest_mode.sql  (Guest Mode, Stage 1)
-- Additive + policy-hardening. Runs on top of 0001/0002/0003/0004.
-- Run ONCE in Supabase SQL Editor.
--
-- Purpose: make Supabase anonymous auth safe. Anonymous users hold
-- the `authenticated` role and a real auth.uid(), so every policy /
-- view / RPC that only checks "is there a uid" silently applied to
-- guests. This migration:
--   1. adds public.is_guest() (reads the JWT is_anonymous claim)
--   2. patches handle_new_user so anon sign-in doesn't violate the
--      NOT NULL / UNIQUE email constraint (otherwise it rolls back)
--   3. adds an AFTER UPDATE conversion-sync trigger (guest -> real)
--   4. adds `and not public.is_guest()` to every own-data policy
--   5. excludes guests from the 3 student views
--   6. rejects guests inside the 5 assessment RPCs
--   7. (optional) hardens users_update_own
-- A commented ROLLBACK block at the very bottom restores the prior
-- definitions verbatim if a guard turns out to be misplaced.
-- ============================================================

-- ============================================================
-- SECTION 0: Guard against running without the base trigger
-- ============================================================
do $$
begin
  if not exists (
    select 1 from information_schema.triggers
    where trigger_name = 'on_auth_user_created'
      and event_object_schema = 'auth'
      and event_object_table = 'users'
  ) then
    raise warning
      'MISSING TRIGGER: on_auth_user_created not found. Run schema.sql / setup first.';
  else
    raise notice 'OK: on_auth_user_created trigger exists.';
  end if;
end $$;

-- ============================================================
-- SECTION 1: public.is_guest() helper
-- SECURITY INVOKER + pinned search_path so its execution context is
-- unambiguous even when called from security_invoker = false views.
-- Returns FALSE (never null) when there is no JWT at all, so an
-- unauthenticated caller is treated as "not a guest" and only sees
-- the public read-only browse policies.
-- ============================================================
create or replace function public.is_guest()
returns boolean
language sql
stable
security invoker
set search_path = public, pg_catalog
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

revoke all on function public.is_guest() from public;
grant execute on function public.is_guest() to authenticated, anon;

-- ============================================================
-- SECTION 2: Patch handle_new_user for anonymous sign-in
-- public.users.email is NOT NULL UNIQUE. Anonymous users have no
-- email, so the original trigger's `new.email` insert threw a NOT
-- NULL violation and rolled back the whole anonymous sign-in.
-- Give anon rows a UUID-keyed placeholder (unique by construction,
-- reserved internal domain) + a "زائر" display name.
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  insert into public.users (id, full_name, email, role)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      case when new.is_anonymous then 'زائر' else 'مستخدم جديد' end
    ),
    coalesce(new.email, new.id::text || '@guest.sheikhy.local'),
    'student'
  );
  return new;
end;
$$;
-- NB: the on_auth_user_created trigger already exists — not recreated.

-- ============================================================
-- SECTION 3: Conversion-sync trigger (guest -> real account)
-- When an anonymous user links an email in place (updateUser), GoTrue
-- sets auth.users.email from null to the real address. Sync it into
-- public.users so the profile row is correct — WITHOUT the client ever
-- writing public.users. The email UPDATE is wrapped so a duplicate
-- surfaces as EMAIL_TAKEN, never a raw 23505 (belt-and-suspenders:
-- GoTrue already rejects a duplicate email before this trigger fires).
-- ============================================================
create or replace function public.handle_anon_conversion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.email is not null then
    begin
      update public.users
         set email     = new.email,
             full_name = coalesce(new.raw_user_meta_data->>'full_name', full_name)
       where id = new.id;
    exception when unique_violation then
      raise exception 'EMAIL_TAKEN' using errcode = '23505';
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_converted on auth.users;
create trigger on_auth_user_converted
  after update on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_anon_conversion();

-- ============================================================
-- SECTION 4: Harden own-data policies (Audit §A) — add not is_guest()
-- ============================================================

-- enrollments
drop policy if exists "enrollments_insert_own" on public.enrollments;
create policy "enrollments_insert_own" on public.enrollments
  for insert with check (auth.uid() = user_id and not public.is_guest());

drop policy if exists "enrollments_select_own_or_admin" on public.enrollments;
create policy "enrollments_select_own_or_admin" on public.enrollments
  for select using ((auth.uid() = user_id and not public.is_guest()) or public.is_admin());

-- lesson_progress
drop policy if exists "progress_upsert_own" on public.lesson_progress;
create policy "progress_upsert_own" on public.lesson_progress
  for all
  using (auth.uid() = user_id and not public.is_guest())
  with check (auth.uid() = user_id and not public.is_guest());

drop policy if exists "progress_select_own_or_admin" on public.lesson_progress;
create policy "progress_select_own_or_admin" on public.lesson_progress
  for select using ((auth.uid() = user_id and not public.is_guest()) or public.is_admin());

-- final_exam_attempts
drop policy if exists "attempts_insert_own" on public.final_exam_attempts;
create policy "attempts_insert_own" on public.final_exam_attempts
  for insert with check (auth.uid() = user_id and not public.is_guest());

drop policy if exists "attempts_select_own_or_admin" on public.final_exam_attempts;
create policy "attempts_select_own_or_admin" on public.final_exam_attempts
  for select using ((auth.uid() = user_id and not public.is_guest()) or public.is_admin());

-- certificates
drop policy if exists "certificates_select_own_or_admin" on public.certificates;
create policy "certificates_select_own_or_admin" on public.certificates
  for select using ((auth.uid() = user_id and not public.is_guest()) or public.is_admin());

-- student_questions
drop policy if exists "questions_insert_own" on public.student_questions;
create policy "questions_insert_own" on public.student_questions
  for insert with check (auth.uid() = user_id and not public.is_guest());

drop policy if exists "questions_select_own" on public.student_questions;
create policy "questions_select_own" on public.student_questions
  for select using (auth.uid() = user_id and not public.is_guest());

-- notification_reads
drop policy if exists "notif_reads_insert_own" on public.notification_reads;
create policy "notif_reads_insert_own" on public.notification_reads
  for insert with check (auth.uid() = user_id and not public.is_guest());

drop policy if exists "notif_reads_select_own" on public.notification_reads;
create policy "notif_reads_select_own" on public.notification_reads
  for select using (auth.uid() = user_id and not public.is_guest());

-- ============================================================
-- SECTION 5: Exclude guests from the student views (Audit §B)
-- Recreated verbatim from 0001 / 0002b_qa_fixes with the guard appended.
-- Guests get zero rows -> quiz tab auto-hides, exam unreachable, Q&A empty.
-- ============================================================

create or replace view public.lesson_quiz_questions_student
  with (security_invoker = false)
as
select
  q.id, q.lesson_id, q.order_index, q.question_text,
  q.choice_a, q.choice_b, q.choice_c, q.choice_d, q.created_at
from public.lessons l
join public.lesson_quiz_questions q on q.lesson_id = l.id
where l.status = 'published'
  and not public.is_guest();
grant select on public.lesson_quiz_questions_student to authenticated;

create or replace view public.final_exam_questions_student
  with (security_invoker = false)
as
select
  q.id, q.book_id, q.order_index, q.question_text,
  q.choice_a, q.choice_b, q.choice_c, q.choice_d, q.created_at
from public.final_exam_questions q
join public.final_exam_settings s on s.book_id = q.book_id
where s.is_published = true
  and not public.is_guest();
grant select on public.final_exam_questions_student to authenticated;

create or replace view public.student_questions_public
as
select
  q.id, q.book_id, q.lesson_id, q.question_text,
  q.answer_text, q.status, q.answered_at, q.created_at
from public.student_questions q
left join public.lessons l on l.id = q.lesson_id
where (q.lesson_id is null or l.status = 'published')
  and not public.is_guest();
grant select on public.student_questions_public to authenticated;

-- ============================================================
-- SECTION 6: Reject guests inside the assessment RPCs (Audit §C)
-- Each is recreated verbatim from 0001 with a guest guard inserted
-- immediately after the existing `v_user_id is null` check.
-- ============================================================

-- 6a. grade_lesson_quiz (admin/preview grader; no attempt stored)
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

-- 6b. submit_final_exam
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

-- 6c. submit_lesson_quiz
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

-- 6d. get_lesson_quiz_review
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

-- 6e. get_final_exam_review
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

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
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
-- SECTION 7: (Optional harden) users_update_own — block guest self-edit.
-- Safe because conversion writes public.users via the SECURITY DEFINER
-- trigger (Section 3), which bypasses RLS. Guests never edit their profile.
-- ============================================================
drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (auth.uid() = id and not public.is_guest());

-- ============================================================
-- SECTION 8: Anonymous-account cleanup — MANUAL RUN ONLY.
-- Not scheduled; run by hand in the SQL editor when purging stale
-- guests. The filter LEADS with is_anonymous = true; age is only a
-- secondary narrowing predicate, never the sole filter — a converted
-- (real) account can never be caught even if it was once a guest.
-- on delete cascade removes the placeholder public.users row.
-- ============================================================
-- delete from auth.users
-- where is_anonymous = true
--   and created_at < now() - interval '30 days';

-- ============================================================
-- ROLLBACK BLOCK — original definitions, verbatim from
-- schema.sql + 0001_app_support.sql + 0002b_qa_fixes.sql + 0003.
-- Uncomment and run this whole block to restore pre-0005 behavior
-- if a guard locks real users out. (Leaves is_guest()/conversion
-- trigger in place — they are inert once the policies are reverted;
-- drop them separately if desired.)
-- ============================================================
/*
-- Own-data policies (schema.sql + 0003)
drop policy if exists "enrollments_insert_own" on public.enrollments;
create policy "enrollments_insert_own" on public.enrollments
  for insert with check (auth.uid() = user_id);
drop policy if exists "enrollments_select_own_or_admin" on public.enrollments;
create policy "enrollments_select_own_or_admin" on public.enrollments
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "progress_upsert_own" on public.lesson_progress;
create policy "progress_upsert_own" on public.lesson_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "progress_select_own_or_admin" on public.lesson_progress;
create policy "progress_select_own_or_admin" on public.lesson_progress
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "attempts_insert_own" on public.final_exam_attempts;
create policy "attempts_insert_own" on public.final_exam_attempts
  for insert with check (auth.uid() = user_id);
drop policy if exists "attempts_select_own_or_admin" on public.final_exam_attempts;
create policy "attempts_select_own_or_admin" on public.final_exam_attempts
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "certificates_select_own_or_admin" on public.certificates;
create policy "certificates_select_own_or_admin" on public.certificates
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "questions_insert_own" on public.student_questions;
create policy "questions_insert_own" on public.student_questions
  for insert with check (auth.uid() = user_id);
drop policy if exists "questions_select_own" on public.student_questions;
create policy "questions_select_own" on public.student_questions
  for select using (auth.uid() = user_id);

drop policy if exists "notif_reads_insert_own" on public.notification_reads;
create policy "notif_reads_insert_own" on public.notification_reads
  for insert with check (auth.uid() = user_id);
drop policy if exists "notif_reads_select_own" on public.notification_reads;
create policy "notif_reads_select_own" on public.notification_reads
  for select using (auth.uid() = user_id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- Views (0001 + 0002b_qa_fixes) — original WHERE without the guest guard
create or replace view public.lesson_quiz_questions_student
  with (security_invoker = false) as
select q.id, q.lesson_id, q.order_index, q.question_text,
       q.choice_a, q.choice_b, q.choice_c, q.choice_d, q.created_at
from public.lessons l
join public.lesson_quiz_questions q on q.lesson_id = l.id
where l.status = 'published';
grant select on public.lesson_quiz_questions_student to authenticated;

create or replace view public.final_exam_questions_student
  with (security_invoker = false) as
select q.id, q.book_id, q.order_index, q.question_text,
       q.choice_a, q.choice_b, q.choice_c, q.choice_d, q.created_at
from public.final_exam_questions q
join public.final_exam_settings s on s.book_id = q.book_id
where s.is_published = true;
grant select on public.final_exam_questions_student to authenticated;

create or replace view public.student_questions_public as
select q.id, q.book_id, q.lesson_id, q.question_text,
       q.answer_text, q.status, q.answered_at, q.created_at
from public.student_questions q
left join public.lessons l on l.id = q.lesson_id
where q.lesson_id is null or l.status = 'published';
grant select on public.student_questions_public to authenticated;

-- NB: the 5 RPCs revert simply by removing the is_guest() guard block;
-- their original bodies live in 0001_app_support.sql, unchanged otherwise.
*/

-- ============================================================
-- End of migration 0005_guest_mode.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0006_lesson_entitlement.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0006_lesson_entitlement.sql  (Guest Mode, Stage 2)
-- Additive. Runs on top of 0005_guest_mode.sql.
--
-- ⚠️ INCIDENT NOTE (reconciled to live state):
-- The ORIGINAL version of this file ALSO replaced the lessons SELECT policy
-- with "lessons_select_entitled", whose USING clause contained a subquery over
-- public.lessons itself (min(order_index) per book). At query time that caused
-- "infinite recursion detected in policy for relation lessons" and broke the
-- app for ALL authenticated users. The policy was manually reverted in the SQL
-- Editor to the base policy:
--
--     create policy "lessons_select_published_or_admin" on public.lessons
--     for select using (public.is_admin() or status = 'published');
--
-- So this file now contains ONLY the part that is safely live: the URL-free
-- `lessons_public` metadata view. The (recursion-safe) entitlement enforcement
-- is deferred to 0007_lesson_entitlement_fix.sql — DO NOT re-add a lessons
-- self-reference to any policy on public.lessons.
--
-- LIVE STATE after this file + the manual revert:
--   • view public.lessons_public                    → present (created here)
--   • policy public.lessons.lessons_select_published_or_admin (base) → active
--   • content-leak protection (entitlement)          → NOT yet in effect
-- ============================================================

-- ------------------------------------------------------------
-- URL-free metadata view for the lesson LIST (readable by all).
-- security_invoker = false: runs as owner so it is unaffected by lessons RLS;
-- its SELECT list (no video_url / audio_url / pdf_url) is the boundary. The
-- has_* booleans expose only media *presence* for the list icons, never URLs.
-- ------------------------------------------------------------
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
  (pdf_url is not null)                      as has_pdf
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;

-- ============================================================
-- End of migration 0006_lesson_entitlement.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0006_notification_scoping.sql
-- ============================================================
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

-- ============================================================
-- SKIPPED: supabase/migrations/0006_test_harness.sql
--   Reason: BEGIN…ROLLBACK test script — produces no permanent state; skipped
-- ============================================================

-- ============================================================
-- SKIPPED: supabase/migrations/0006b_notification_scoping.sql
--   Reason: truncated 2-line stub (header comment only); skipped
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0007_lesson_entitlement_fix.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0007_lesson_entitlement_fix.sql  (Guest Mode, Stage 2)
--
-- ✅ APPLIED 2026-09-08 — approved in writing after the TEST HARNESS (bottom of
--    this file) passed all three claim variants (guest / enrolled / unenrolled)
--    with no SQLSTATE 42P17. This IS the live lessons SELECT policy. The active
--    statements below (function + policy swap) are the migration; the harness at
--    the bottom stays commented, retained for the record.
--
-- Purpose: re-introduce lesson-content entitlement WITHOUT the recursion that
-- broke 0006. Closes the leak where any authenticated session (guest or
-- registered-not-enrolled) could read every lesson's video_url/audio_url/pdf_url
-- via the base `lessons` table.
--
-- ── Why 0006 recursed ──────────────────────────────────────
-- The 0006 policy USING clause contained:
--     order_index = (select min(l2.order_index) from public.lessons l2
--                    where l2.book_id = lessons.book_id and l2.status='published')
-- Evaluating that policy for a row of `lessons` runs a subquery that itself
-- reads `public.lessons`. RLS is enabled on lessons, so that inner read is
-- ALSO subject to the SAME policy, whose USING clause again reads lessons…
-- → unbounded self-application → Postgres aborts with SQLSTATE 42P17
-- "infinite recursion detected in policy for relation lessons".
-- (The enrollments EXISTS did NOT recurse — different table, no cycle.)
-- It only affected real users because the SQL Editor runs as the table OWNER,
-- which bypasses RLS — so the policy is never evaluated there. It fires only
-- for the `authenticated`/`anon` roles, i.e. actual app traffic.
--
-- ── The fix: move the lessons read into a SECURITY DEFINER function ──
-- A SECURITY DEFINER function owned by the table owner bypasses RLS on lessons
-- when it reads the table, so the policy no longer self-applies. This is the
-- SAME mechanism the existing public.is_admin() relies on (it reads public.users
-- from inside users' own policies without recursing). SECURITY DEFINER SQL
-- functions are also NOT inlined by the planner, so the subquery can't be
-- folded back into the policy expression.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Entitlement helper — reads lessons/enrollments with RLS bypassed.
-- ------------------------------------------------------------
create or replace function public.can_read_lesson(p_lesson_id uuid, p_book_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select
    -- the book's first published lesson is open to everyone (incl. guests)
    p_lesson_id = (
      select l.id
      from public.lessons l
      where l.book_id = p_book_id and l.status = 'published'
      order by l.order_index asc, l.id asc
      limit 1
    )
    -- or the caller is enrolled in the book (guests hold no enrollment rows)
    or exists (
      select 1 from public.enrollments e
      where e.book_id = p_book_id and e.user_id = auth.uid()
    );
$$;

revoke all on function public.can_read_lesson(uuid, uuid) from public;
grant execute on function public.can_read_lesson(uuid, uuid) to authenticated, anon;

-- ------------------------------------------------------------
-- 2. Swap the base lessons policy. The USING clause NO LONGER references
--    public.lessons directly — the only lessons read is inside the
--    SECURITY DEFINER function above (RLS-bypassed → no recursion).
-- ------------------------------------------------------------
drop policy if exists "lessons_select_published_or_admin" on public.lessons;
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_entitled" on public.lessons
for select using (
  public.is_admin()
  or (status = 'published' and public.can_read_lesson(id, book_id))
);

-- ============================================================
-- ROLLBACK (restore the currently-live base policy):
-- ============================================================
/*
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_published_or_admin" on public.lessons
  for select using (public.is_admin() or status = 'published');
drop function if exists public.can_read_lesson(uuid, uuid);
*/

-- ============================================================
-- ✅ TEST HARNESS — run this FIRST, verbatim, in the SQL Editor. It applies the
-- fix, exercises it AS a real authenticated user (which is what reproduces the
-- recursion — the editor's own postgres role bypasses RLS and would hide it),
-- then ROLLS BACK so nothing persists. If it completes without SQLSTATE 42P17,
-- the recursion is gone. EXPLAIN ANALYZE reports the per-row cost you asked for.
--
-- Replace <REAL_USER_UUID> with an existing public.users.id. To exercise each
-- branch, run the block three times varying the claims:
--   • guest:            "is_anonymous":true  (sees only first lessons)
--   • registered/enrolled: a uid that HAS enrollments (sees all their lessons)
--   • registered/none:  a uid with no enrollments (sees only first lessons)
-- ============================================================
/*
begin;

create or replace function public.can_read_lesson(p_lesson_id uuid, p_book_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_catalog as $fn$
  select p_lesson_id = (
      select l.id from public.lessons l
      where l.book_id = p_book_id and l.status = 'published'
      order by l.order_index asc, l.id asc limit 1)
    or exists (select 1 from public.enrollments e
               where e.book_id = p_book_id and e.user_id = auth.uid());
$fn$;
grant execute on function public.can_read_lesson(uuid, uuid) to authenticated, anon;

drop policy if exists "lessons_select_published_or_admin" on public.lessons;
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_entitled" on public.lessons
for select using (
  public.is_admin()
  or (status = 'published' and public.can_read_lesson(id, book_id))
);

-- Become a real end-user so RLS actually runs (this is the step 0006 needed):
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<REAL_USER_UUID>","role":"authenticated","is_anonymous":false}';

-- Must NOT raise "infinite recursion detected in policy for relation lessons":
explain analyze
select id, book_id, order_index
from public.lessons
where status = 'published'
limit 50;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0007_lesson_entitlement_fix.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0008_lesson_has_quiz_flag.sql
-- ============================================================
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

