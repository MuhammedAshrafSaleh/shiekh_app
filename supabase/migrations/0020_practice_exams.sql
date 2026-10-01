-- ============================================================
-- Sheikhy — Companion Migration 0020_practice_exams.sql
-- Additive only — runs on top of the base schema.sql + 0001–0019.
-- Run this ONCE in the Supabase SQL Editor.
--
-- Adds the student "Practice Exams" (اختبر نفسك) feature. Creates ONLY
-- new objects — it does NOT alter or replace any existing table, view,
-- RPC, or the official lesson-quiz / final-exam / bank-import code.
--
--   1. practice_attempts        — one row per SUBMITTED practice exam
--   2. prune_practice_attempts  — trigger keeping only the last 10 per user
--   3. loading_quotes           — admin-managed motivational texts + seed
--   4. get_practice_eligible_lessons()  — lessons the caller may practice
--   5. submit_practice_attempt(...)     — server-side grading + insert
--   6. get_practice_attempt_review(...) — reconstruct a past attempt review
--
-- Isolation: practice writes touch ONLY practice_attempts. Nothing here
-- writes to lesson_progress, lesson_quiz_attempts, final_exam_attempts,
-- achievements, or stats.
--
-- Pool/eligibility predicate parity: everywhere questions are counted,
-- selected, or validated we apply the SAME filter as the existing
-- lesson_quiz_questions_student view (0014):
--     lessons.status = 'published'
--   AND lesson_quiz_questions.ai_review_status = 'approved'
--   AND an enrollment row exists for (auth.uid(), book_id)
-- so the client's max-count slider equals the real, gradable pool.
-- ============================================================

-- ------------------------------------------------------------
-- 1. practice_attempts
-- ------------------------------------------------------------
create table if not exists public.practice_attempts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  score_percentage  int  not null,
  correct_count     int  not null,
  total_count       int  not null,
  lesson_ids        uuid[] not null,          -- derived server-side from the graded questions
  question_order    uuid[] not null,          -- ordered question_ids, valid questions only
  answers           jsonb  not null,          -- { "<question_id>": "a|b|c|d" } valid+answered only
  breakdown         jsonb  not null,          -- [ {lesson_id, lesson_title, correct, total} ]
  duration_seconds  int  not null,            -- actual elapsed time, always recorded
  time_limit_minutes int,                     -- null when the timer was off
  created_at        timestamptz not null default now(),

  constraint practice_attempts_counts_chk
    check (total_count > 0
           and correct_count >= 0
           and correct_count <= total_count),
  constraint practice_attempts_duration_chk
    check (duration_seconds >= 0),
  constraint practice_attempts_time_limit_chk
    check (time_limit_minutes is null
           or (time_limit_minutes between 15 and 120
               and time_limit_minutes % 5 = 0))
);

create index if not exists idx_practice_attempts_user
  on public.practice_attempts(user_id, created_at desc);

alter table public.practice_attempts enable row level security;

-- Students may READ only their own attempts. There is deliberately NO
-- insert/update/delete policy: rows are created exclusively inside the
-- SECURITY DEFINER submit_practice_attempt RPC (so scores can't be
-- forged from the client), and pruning is trigger-owned.
drop policy if exists "practice_attempts_select_own" on public.practice_attempts;
create policy "practice_attempts_select_own" on public.practice_attempts
  for select using (user_id = auth.uid());

-- ------------------------------------------------------------
-- 2. Keep only the last 10 attempts per student (free-plan storage cap)
-- ------------------------------------------------------------
create or replace function public.prune_practice_attempts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.practice_attempts
  where user_id = NEW.user_id
    and id not in (
      select id from public.practice_attempts
      where user_id = NEW.user_id
      order by created_at desc
      limit 10
    );
  return NEW;
end;
$$;

drop trigger if exists trg_prune_practice_attempts on public.practice_attempts;
create trigger trg_prune_practice_attempts
  after insert on public.practice_attempts
  for each row execute function public.prune_practice_attempts();

-- ------------------------------------------------------------
-- 3. loading_quotes — admin-managed motivational texts + seed
-- ------------------------------------------------------------
create table if not exists public.loading_quotes (
  id          uuid primary key default gen_random_uuid(),
  text        text not null,
  source      text,
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create index if not exists idx_loading_quotes_active
  on public.loading_quotes(is_active, sort_order);

alter table public.loading_quotes enable row level security;

drop policy if exists "loading_quotes_read" on public.loading_quotes;
create policy "loading_quotes_read" on public.loading_quotes
  for select using (is_active = true or public.is_admin());

drop policy if exists "loading_quotes_admin_write" on public.loading_quotes;
create policy "loading_quotes_admin_write" on public.loading_quotes
  for all using (public.is_admin()) with check (public.is_admin());

-- Seed the 3 fully-diacritized defaults (idempotent: only when empty).
insert into public.loading_quotes (text, source, sort_order, is_active)
select v.text, v.source, v.sort_order, true
from (values
  ('«مَن يُرِدِ اللهُ بِهِ خَيْرًا يُفَقِّهْهُ فِي الدِّينِ»', 'متفق عليه', 1),
  ('﴿وَأَعِدُّوا لَهُم مَّا اسْتَطَعْتُم مِّن قُوَّةٍ﴾', 'الأنفال: 60', 2),
  ('﴿إِنَّمَا يَخْشَى اللَّهَ مِنْ عِبَادِهِ الْعُلَمَاءُ﴾', 'فاطر: 28', 3)
) as v(text, source, sort_order)
where not exists (select 1 from public.loading_quotes);

-- ------------------------------------------------------------
-- 4. get_practice_eligible_lessons()
--    Lessons the caller has SUBMITTED the official quiz for (any
--    lesson_quiz_attempts row) that still hold >= 1 gradable question
--    under the shared predicate. question_count matches the real pool.
-- ------------------------------------------------------------
create or replace function public.get_practice_eligible_lessons()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_user_id uuid := auth.uid();
  v_result  jsonb;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  -- Ordered by book, then the lesson's real display order (order_index) —
  -- NOT alphabetically by title (Arabic "المحاضرة 10" would precede "2").
  select coalesce(jsonb_agg(r order by book_title, order_index), '[]'::jsonb)
  into v_result
  from (
    select
      b.title       as book_title,
      l.order_index as order_index,
      jsonb_build_object(
        'lesson_id',      l.id,
        'lesson_title',   l.title,
        'book_title',     b.title,
        'question_count', count(q.id)
      ) as r
    from public.lessons l
    join public.books b on b.id = l.book_id
    join public.lesson_quiz_questions q on q.lesson_id = l.id
    where l.status = 'published'
      and q.ai_review_status = 'approved'
      and exists (
        select 1 from public.enrollments e
        where e.book_id = l.book_id and e.user_id = v_user_id
      )
      and exists (
        select 1 from public.lesson_quiz_attempts a
        where a.user_id = v_user_id and a.lesson_id = l.id
      )
    group by l.id, l.title, l.order_index, b.title
    having count(q.id) >= 1
  ) s;

  return v_result;
end;
$$;

revoke all on function public.get_practice_eligible_lessons() from public;
revoke execute on function public.get_practice_eligible_lessons() from anon;
grant execute on function public.get_practice_eligible_lessons() to authenticated;

-- ------------------------------------------------------------
-- 5. submit_practice_attempt(...)
--    Grades server-side, inserts one attempt, returns the review payload.
--    p_lesson_ids is intentionally NOT a parameter — the lesson set is
--    derived from the questions and stored in lesson_ids.
--
--    Validation on the ORIGINAL p_question_order:
--      * length 20..100
--      * no duplicate ids
--      * every answer key is a member of p_question_order
--
--    Per-question resolution:
--      * not found (deleted mid-exam)          -> silently excluded
--      * exists but lesson NOT completed         -> TAMPERING -> reject all
--      * exists, completed, fails pool predicate -> silently excluded
--      * exists, completed, passes predicate     -> graded
--    If zero valid questions remain -> reject. Unanswered valid = wrong.
-- ------------------------------------------------------------
create or replace function public.submit_practice_attempt(
  p_question_order    uuid[],
  p_answers           jsonb,
  p_duration_seconds  int,
  p_time_limit_minutes int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id     uuid := auth.uid();
  v_answers     jsonb := coalesce(p_answers, '{}'::jsonb);
  v_n           int := coalesce(array_length(p_question_order, 1), 0);
  v_total       int;
  v_correct     int;
  v_score       int;
  v_lesson_ids  uuid[];
  v_qorder      uuid[];
  v_stored_ans  jsonb;
  v_breakdown   jsonb;
  v_review      jsonb;
  v_attempt_id  uuid;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if public.is_guest() then
    raise exception 'GUESTS_NOT_ALLOWED' using errcode = '42501';
  end if;

  -- --- Validate the original request ---------------------------------
  if v_n < 20 or v_n > 100 then
    raise exception 'INVALID_COUNT' using errcode = 'P0001';
  end if;

  if v_n <> (select count(distinct x) from unnest(p_question_order) x) then
    raise exception 'DUPLICATE_QUESTIONS' using errcode = 'P0002';
  end if;

  if p_duration_seconds is null or p_duration_seconds < 0 then
    raise exception 'INVALID_DURATION' using errcode = 'P0003';
  end if;

  if exists (
    select 1 from jsonb_object_keys(v_answers) as k
    where k not in (select (qid)::text from unnest(p_question_order) as qid)
  ) then
    raise exception 'INVALID_ANSWER_KEYS' using errcode = 'P0004';
  end if;

  -- Answer VALUES must be a single choice letter — blocks storing
  -- arbitrary/oversized strings in practice_attempts.answers.
  if exists (
    select 1 from jsonb_each_text(v_answers) as kv(k, val)
    where val not in ('a', 'b', 'c', 'd')
  ) then
    raise exception 'INVALID_ANSWER_VALUE' using errcode = 'P0006';
  end if;

  -- --- Anti-tamper: an EXISTING question whose lesson the caller has
  --     never completed is not a mid-exam deletion — reject the whole
  --     submission. (Non-existent ids can't be attributed to a lesson,
  --     so they are simply excluded below, not treated as tampering.)
  if exists (
    select 1
    from unnest(p_question_order) as qid
    join public.lesson_quiz_questions q on q.id = qid
    where not exists (
      select 1 from public.lesson_quiz_attempts a
      where a.user_id = v_user_id and a.lesson_id = q.lesson_id
    )
  ) then
    raise exception 'TAMPERING' using errcode = '42501';
  end if;

  -- --- Resolve the valid, gradable questions (ordered) ---------------
  create temporary table _pa_valid on commit drop as
  select
    o.ord,
    q.id            as qid,
    q.lesson_id,
    l.title         as lesson_title,
    q.question_text,
    q.choice_a, q.choice_b, q.choice_c, q.choice_d,
    q.correct_choice,
    (v_answers ->> q.id::text) as user_answer,
    ( (v_answers ->> q.id::text) is not null
      and (v_answers ->> q.id::text) = q.correct_choice ) as is_correct
  from unnest(p_question_order) with ordinality as o(qid, ord)
  join public.lesson_quiz_questions q on q.id = o.qid
  join public.lessons l on l.id = q.lesson_id and l.status = 'published'
  where q.ai_review_status = 'approved'
    and exists (
      select 1 from public.enrollments e
      where e.book_id = l.book_id and e.user_id = v_user_id
    );

  select count(*), count(*) filter (where is_correct)
    into v_total, v_correct
  from _pa_valid;

  if coalesce(v_total, 0) = 0 then
    raise exception 'NO_VALID_QUESTIONS' using errcode = 'P0005';
  end if;

  v_score := round(v_correct::numeric / v_total * 100);

  select array_agg(qid order by ord) into v_qorder from _pa_valid;
  select array_agg(distinct lesson_id) into v_lesson_ids from _pa_valid;

  select coalesce(
           jsonb_object_agg(qid::text, user_answer)
             filter (where user_answer is not null),
           '{}'::jsonb)
    into v_stored_ans
  from _pa_valid;

  select jsonb_agg(
           jsonb_build_object(
             'lesson_id',    s.lesson_id,
             'lesson_title', s.lesson_title,
             'correct',      s.correct,
             'total',        s.total
           ) order by s.lesson_title)
    into v_breakdown
  from (
    select lesson_id, lesson_title,
           count(*) filter (where is_correct) as correct,
           count(*)                           as total
    from _pa_valid
    group by lesson_id, lesson_title
  ) s;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'question_id',    qid,
               'question_text',  question_text,
               'choice_a',       choice_a,
               'choice_b',       choice_b,
               'choice_c',       choice_c,
               'choice_d',       choice_d,
               'correct_choice', correct_choice,
               'user_answer',    user_answer,
               'is_correct',     is_correct,
               'lesson_title',   lesson_title,
               'is_deleted',     false
             ) order by ord),
           '[]'::jsonb)
    into v_review
  from _pa_valid;

  insert into public.practice_attempts
    (user_id, score_percentage, correct_count, total_count,
     lesson_ids, question_order, answers, breakdown,
     duration_seconds, time_limit_minutes)
  values
    (v_user_id, v_score, v_correct, v_total,
     v_lesson_ids, v_qorder, v_stored_ans, v_breakdown,
     p_duration_seconds, p_time_limit_minutes)
  returning id into v_attempt_id;

  drop table if exists _pa_valid;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score',      v_score,
    'correct',    v_correct,
    'total',      v_total,
    'breakdown',  coalesce(v_breakdown, '[]'::jsonb),
    'review',     v_review
  );
end;
$$;

revoke all on function
  public.submit_practice_attempt(uuid[], jsonb, int, int) from public;
revoke execute on function
  public.submit_practice_attempt(uuid[], jsonb, int, int) from anon;
grant execute on function
  public.submit_practice_attempt(uuid[], jsonb, int, int) to authenticated;

-- ------------------------------------------------------------
-- 6. get_practice_attempt_review(p_attempt_id)
--    Reconstructs a past attempt's review from stored data. Only the
--    owner may read. Questions deleted since submission return a
--    tombstone row (is_deleted = true); score/breakdown were frozen at
--    submit time so summaries stay correct regardless.
-- ------------------------------------------------------------
create or replace function public.get_practice_attempt_review(
  p_attempt_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_user_id uuid := auth.uid();
  v_att     public.practice_attempts%rowtype;
  v_review  jsonb;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select * into v_att
  from public.practice_attempts
  where id = p_attempt_id and user_id = v_user_id;

  if not found then
    raise exception 'ATTEMPT_NOT_FOUND' using errcode = 'P0005';
  end if;

  select coalesce(jsonb_agg(rev order by ord), '[]'::jsonb)
    into v_review
  from (
    select
      o.ord,
      case
        when q.id is null then
          jsonb_build_object(
            'question_id', o.qid,
            'user_answer', v_att.answers ->> o.qid::text,
            'is_deleted',  true
          )
        else
          jsonb_build_object(
            'question_id',    q.id,
            'question_text',  q.question_text,
            'choice_a',       q.choice_a,
            'choice_b',       q.choice_b,
            'choice_c',       q.choice_c,
            'choice_d',       q.choice_d,
            'correct_choice', q.correct_choice,
            'user_answer',    v_att.answers ->> q.id::text,
            'is_correct',     ( (v_att.answers ->> q.id::text) is not null
                                and (v_att.answers ->> q.id::text) = q.correct_choice ),
            'lesson_title',   l.title,
            'is_deleted',     false
          )
      end as rev
    from unnest(v_att.question_order) with ordinality as o(qid, ord)
    left join public.lesson_quiz_questions q on q.id = o.qid
    left join public.lessons l on l.id = q.lesson_id
  ) s;

  return jsonb_build_object(
    'attempt_id',         v_att.id,
    'score',              v_att.score_percentage,
    'correct',            v_att.correct_count,
    'total',              v_att.total_count,
    'breakdown',          v_att.breakdown,
    'duration_seconds',   v_att.duration_seconds,
    'time_limit_minutes', v_att.time_limit_minutes,
    'created_at',         v_att.created_at,
    'review',             v_review
  );
end;
$$;

revoke all on function public.get_practice_attempt_review(uuid) from public;
revoke execute on function public.get_practice_attempt_review(uuid) from anon;
grant execute on function public.get_practice_attempt_review(uuid) to authenticated;
