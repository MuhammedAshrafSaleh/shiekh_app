-- ============================================================
-- docs/full_setup.sql  —  Sheikhy complete database setup
-- ============================================================
-- WHAT THIS FILE IS
-- Authoritative concatenation of every real migration in
-- supabase/migrations/, in the order they must be applied on
-- a fresh Supabase project.  Equivalent to running the CLI
--   supabase db push
-- but works via the SQL Editor for operators without the CLI.
--
-- OBJECT ORDER IS SIGNIFICANT
-- 0000_baseline.sql creates tables BEFORE functions because
-- is_admin() is LANGUAGE sql and its body is validated at CREATE
-- time (it reads public.users).  Do not reorder.
--
-- WHAT IS SKIPPED (and why)
--   0002b_qa_fixes.sql  — duplicate of 0002_qa_fixes (identical SQL)
--   0006_test_harness.sql   — BEGIN…ROLLBACK; no permanent state
--   0006b_notification_scoping.sql — truncated 2-line stub
--   0011_test_harness.sql   — BEGIN…ROLLBACK; no permanent state
--
-- STATEMENTS THAT REQUIRE ELEVATED PRIVILEGES
--   [!] CREATE TRIGGER … ON auth.users  (in 0000_baseline.sql)
--       Requires the postgres (superuser) role.  The Supabase SQL
--       Editor runs as postgres, so it succeeds there.  A migration
--       tool connecting as a lower-privilege role must be granted
--       TRIGGER on auth.users or run this statement manually.
--   [!] REVOKE … FROM public  (in 0023_revoke_public_exec.sql)
--       Requires the function owner role; succeeds as postgres.
--
-- SPLIT FILES
-- This same content is also split into four self-contained parts
-- (each assumes the previous part succeeded), in run order:
--   docs/full_setup_part1.sql  — 0000–0004 (STARTS WITH THE BASELINE)
--   docs/full_setup_part2.sql  — 0005–0008
--   docs/full_setup_part3.sql  — 0009–0016
--   docs/full_setup_part4.sql  — 0017–0023
-- Part boundaries are marked below with
--   -- ===== END OF PART N / START OF PART M =====
--
-- Generated: 2026-10-25
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0000_baseline.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0000_baseline.sql
--
-- PURPOSE: Establish the state that existed BEFORE 0001_app_support.sql
-- was applied.  Running this file on a brand-new Supabase project followed
-- by migrations 0001 → 0023 (ascending) reproduces the live schema exactly.
--
-- OBJECT ORDER (important):
--   1. ENUMs
--   2. Base tables (no table DDL references any function, so tables are
--      created first)
--   3. Functions — is_admin() is LANGUAGE sql and its body is validated at
--      CREATE time, so public.users must already exist before it is defined.
--      Creating all functions AFTER the tables avoids a "relation does not
--      exist" error on a fresh database.
--   4. AFTER INSERT trigger on auth.users → handle_new_user()
--   5. Base indexes
--   6. BEFORE UPDATE updated_at triggers (need set_updated_at())
--   7. RLS enable
--   8. Base RLS policies (need is_admin())
--
-- WHAT THIS FILE CREATES:
--   • All five custom ENUMs
--   • All 16 base tables in dependency order, each in its PRE-MIGRATION
--     column shape (columns added later are omitted here and added by the
--     numbered migrations that introduce them)
--   • Three base functions: set_updated_at(), is_admin(), handle_new_user()
--     (original pre-guest-mode body, replaced by 0005_guest_mode.sql)
--   • rls_auto_enable() event-trigger function (present in live DB; the
--     matching CREATE EVENT TRIGGER is not captured in pg_dump --schema public
--     because event triggers are cluster-level objects — see reconciliation
--     notes at the bottom of this file)
--   • AFTER INSERT trigger on auth.users → handle_new_user()
--   • Base indexes (only on base tables; migration-owned tables add their own)
--   • BEFORE UPDATE updated_at triggers on base tables
--   • RLS enabled on every base table + base policies (pre-0003/0005/0006/0007/0010)
-- ============================================================

-- ============================================================
-- SECTION 1: ENUMs
-- ============================================================

create type public.notification_type as enum (
  'general',
  'live_stream',
  'new_lesson',
  'reminder',
  'achievement'
);

create type public.publish_status as enum (
  'draft',
  'published'
);

create type public.question_status as enum (
  'pending',
  'answered'
);

create type public.review_status as enum (
  'in_review',
  'completed'
);

create type public.user_role as enum (
  'student',
  'admin'
);

-- ============================================================
-- SECTION 2: BASE TABLES  (dependency order)
-- Created BEFORE the functions because is_admin() (LANGUAGE sql)
-- references public.users and its body is validated at CREATE time.
-- No base table DDL references any function, so this ordering is safe.
-- Column shapes reflect the state BEFORE any numbered migration;
-- columns added by later migrations are intentionally omitted here
-- and introduced by those migrations.
-- ============================================================

-- -----------------------------------------------------------
-- 2a. users — mirrors auth.users, one row per account.
--     No changes to this table by any numbered migration.
-- -----------------------------------------------------------
create table public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       public.user_role not null default 'student',
  full_name  text not null,
  email      text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table  public.users            is 'بيانات المستخدمين - طالب أو أدمن في جدول واحد';
comment on column public.users.role       is 'يحدد التوجيه بعد تسجيل الدخول: student أو admin';

-- -----------------------------------------------------------
-- 2b. sections — scientific topic buckets.
--     No changes to this table by any numbered migration.
-- -----------------------------------------------------------
create table public.sections (
  id         uuid primary key default extensions.uuid_generate_v4(),
  name       text not null,
  icon       text not null,
  description text,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.sections is 'الأقسام العلمية مثل العقيدة والفقه والتفسير';

-- -----------------------------------------------------------
-- 2c. books — one book per section.
--     No changes to this table by any numbered migration.
-- -----------------------------------------------------------
create table public.books (
  id              uuid primary key default extensions.uuid_generate_v4(),
  section_id      uuid not null references public.sections(id) on delete restrict,
  title           text not null,
  description     text,
  cover_image_url text,
  status          public.publish_status not null default 'draft',
  review_status   public.review_status  not null default 'in_review',
  is_featured     boolean not null default false,
  featured_order  integer,
  created_by      uuid references public.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on column public.books.status        is 'منشور أو مسودة - يتحكم في ظهور الكتاب للطلاب';
comment on column public.books.review_status is 'مكتمل أو قيد المراجعة - مؤشر داخلي للأدمن فقط';
comment on column public.books.is_featured   is 'يظهر في قائمة أهم الكتب بالصفحة الرئيسية';

-- -----------------------------------------------------------
-- 2d. lessons — baseline shape.
--     Columns added later:
--       • 0011: transcript, transcript_status, transcript_error,
--                transcript_generated_at
--       • 0012: pdf_url comment updated to "DEPRECATED"
--       • 0015: video_duration_minutes, audio_duration_minutes
-- -----------------------------------------------------------
create table public.lessons (
  id          uuid primary key default extensions.uuid_generate_v4(),
  book_id     uuid not null references public.books(id) on delete cascade,
  order_index int  not null,
  title       text not null,
  description text,
  video_url   text,
  audio_url   text,
  pdf_url     text,
  audio_only  boolean not null default false,
  status      public.publish_status not null default 'draft',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (book_id, order_index)
);

comment on column public.lessons.video_url  is 'لينك يوتيوب Unlisted';
comment on column public.lessons.audio_url  is 'لينك Google Drive - يُحوَّل لصيغة تحميل مباشر في التطبيق';
comment on column public.lessons.audio_only is 'هذا الدرس صوت فقط بدون فيديو';

-- -----------------------------------------------------------
-- 2e. enrollments — student book registrations.
--     No changes by any migration (policies changed by 0005).
-- -----------------------------------------------------------
create table public.enrollments (
  id          uuid primary key default extensions.uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  book_id     uuid not null references public.books(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  unique (user_id, book_id)
);

comment on table public.enrollments is 'تسجيل الطالب في كتاب - يُنشأ بعد تأكيد Confirmation Dialog';

-- -----------------------------------------------------------
-- 2f. lesson_quiz_questions — baseline shape.
--     Columns added later:
--       • 0011: source, ai_review_status, difficulty, explanation,
--                source_quote, reviewed_by, reviewed_at
--       • 0019: source_question_id
-- -----------------------------------------------------------
create table public.lesson_quiz_questions (
  id             uuid primary key default extensions.uuid_generate_v4(),
  lesson_id      uuid not null references public.lessons(id) on delete cascade,
  order_index    int  not null default 0,
  question_text  text not null,
  choice_a       text not null,
  choice_b       text not null,
  choice_c       text not null,
  choice_d       text not null,
  correct_choice char(1) not null
    check (correct_choice in ('a','b','c','d')),
  created_at     timestamptz not null default now()
);

comment on table public.lesson_quiz_questions
  is 'أسئلة اختبار الدرس القصير - تُستخدم أيضًا كبنك أسئلة للاختبار الشامل';

-- -----------------------------------------------------------
-- 2g. lesson_quiz_attempts — records per-attempt results.
--     No structural changes by any migration.
-- -----------------------------------------------------------
create table public.lesson_quiz_attempts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users(id)   on delete cascade,
  lesson_id      uuid not null references public.lessons(id) on delete cascade,
  attempt_number int  not null,
  score_percentage int not null,
  passed         boolean not null,
  answers        jsonb not null default '{}',
  submitted_at   timestamptz not null default now(),
  unique (user_id, lesson_id, attempt_number)
);

-- -----------------------------------------------------------
-- 2h. final_exam_settings — per-book exam configuration.
--     No structural changes by any migration (policies only).
-- -----------------------------------------------------------
create table public.final_exam_settings (
  book_id            uuid primary key references public.books(id) on delete cascade,
  time_limit_minutes int     not null default 30,
  passing_percentage int     not null default 70,
  max_attempts       int     not null default 2,
  is_published       boolean not null default false,
  updated_at         timestamptz not null default now()
);

comment on table public.final_exam_settings
  is 'إعدادات الاختبار الشامل لكل كتاب: الوقت، نسبة النجاح، عدد المحاولات';

-- -----------------------------------------------------------
-- 2i. final_exam_questions — baseline shape.
--     FK change in 0021: source_quiz_question_id FK changes
--     from the default ON DELETE NO ACTION to ON DELETE SET NULL.
-- -----------------------------------------------------------
create table public.final_exam_questions (
  id                      uuid primary key default extensions.uuid_generate_v4(),
  book_id                 uuid not null references public.books(id) on delete cascade,
  order_index             int  not null default 0,
  question_text           text not null,
  choice_a                text not null,
  choice_b                text not null,
  choice_c                text not null,
  choice_d                text not null,
  correct_choice          char(1) not null
    check (correct_choice in ('a','b','c','d')),
  source_quiz_question_id uuid
    references public.lesson_quiz_questions(id),   -- ON DELETE NO ACTION (default); changed to SET NULL by 0021
  created_at              timestamptz not null default now()
);

comment on column public.final_exam_questions.source_quiz_question_id
  is 'مرجع اختياري للسؤال الأصلي في بنك الأسئلة لو تم الاستيراد منه';

-- -----------------------------------------------------------
-- 2j. final_exam_attempts — stores each graded attempt.
--     No structural changes by any migration (policies by 0005).
-- -----------------------------------------------------------
create table public.final_exam_attempts (
  id               uuid primary key default extensions.uuid_generate_v4(),
  user_id          uuid not null references public.users(id)  on delete cascade,
  book_id          uuid not null references public.books(id)  on delete cascade,
  attempt_number   int  not null,
  score_percentage int  not null,
  passed           boolean not null,
  answers          jsonb not null default '{}',
  started_at       timestamptz not null default now(),
  submitted_at     timestamptz
);

comment on column public.final_exam_attempts.answers
  is 'JSON: { "question_id": "chosen_choice" }';

-- -----------------------------------------------------------
-- 2k. certificates — issued on passing the final exam.
--     No structural changes by any migration.
-- -----------------------------------------------------------
create table public.certificates (
  id                    uuid primary key default extensions.uuid_generate_v4(),
  user_id               uuid not null references public.users(id)  on delete cascade,
  book_id               uuid not null references public.books(id)  on delete cascade,
  final_exam_attempt_id uuid
    references public.final_exam_attempts(id),
  final_score           int  not null,
  grade_label           text,
  issued_at             timestamptz not null default now(),
  pdf_url               text,
  unique (user_id, book_id)
);

comment on column public.certificates.grade_label is 'مثل: ممتاز، جيد جداً، جيد';

-- -----------------------------------------------------------
-- 2l. lesson_progress — per-student per-lesson progress.
--     Columns added later:
--       • 0009: video_position_seconds, audio_position_seconds
-- -----------------------------------------------------------
create table public.lesson_progress (
  id                    uuid primary key default extensions.uuid_generate_v4(),
  user_id               uuid not null references public.users(id)   on delete cascade,
  lesson_id             uuid not null references public.lessons(id) on delete cascade,
  completed             boolean not null default false,
  last_position_seconds int     default 0,
  completed_at          timestamptz,
  updated_at            timestamptz not null default now(),
  unique (user_id, lesson_id)
);

comment on column public.lesson_progress.last_position_seconds
  is 'لاستئناف الفيديو من حيث توقف الطالب';

-- -----------------------------------------------------------
-- 2m. notifications — baseline shape (no target_user_id).
--     Column added later:
--       • 0006: target_user_id uuid references users(id) ON DELETE CASCADE
--     Policy change:
--       • 0006: notifications_select_all → notifications_select_scoped
-- -----------------------------------------------------------
create table public.notifications (
  id         uuid primary key default extensions.uuid_generate_v4(),
  type       public.notification_type not null default 'general',
  title      text not null,
  body       text not null,
  link_url   text,
  send_at    timestamptz not null default now(),
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on column public.notifications.link_url is 'لينك بث مباشر أو لينك كتاب/درس معيّن';
comment on column public.notifications.send_at  is 'يدعم الإرسال الفوري أو المجدول';

-- -----------------------------------------------------------
-- 2n. notification_reads — tracks which notifications a user read.
--     No structural changes by any migration (policies by 0005).
-- -----------------------------------------------------------
create table public.notification_reads (
  id              uuid primary key default extensions.uuid_generate_v4(),
  user_id         uuid not null references public.users(id)         on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  read_at         timestamptz not null default now(),
  unique (user_id, notification_id)
);

comment on table public.notification_reads
  is 'قراءة الإشعارات - يُستخدم لزر "تحديد الكل كمقروء"';

-- -----------------------------------------------------------
-- 2o. student_questions — baseline shape.
--     lesson_id is NOT NULL here; made nullable by 0002_qa_fixes.sql.
--     Policy change:
--       • 0003: adds questions_select_own
--       • 0005: adds not is_guest() to questions_insert_own /
--                questions_select_own
--       • 0010: adds questions_admin_delete
-- -----------------------------------------------------------
create table public.student_questions (
  id            uuid primary key default extensions.uuid_generate_v4(),
  user_id       uuid not null references public.users(id)   on delete cascade,
  book_id       uuid not null references public.books(id)   on delete cascade,
  lesson_id     uuid not null references public.lessons(id) on delete cascade,   -- NOT NULL; 0002_qa_fixes makes this nullable
  question_text text not null,
  answer_text   text,
  status        public.question_status not null default 'pending',
  answered_at   timestamptz,
  created_at    timestamptz not null default now()
);

comment on table public.student_questions
  is 'أسئلة الطلاب: تُدخل في سياق درس، تُعرض موحّدة على مستوى الكتاب';

-- -----------------------------------------------------------
-- 2p. home_banners — featured content carousel on home screen.
--     No structural changes by any migration.
-- -----------------------------------------------------------
create table public.home_banners (
  id              uuid primary key default extensions.uuid_generate_v4(),
  title           text not null,
  description     text,
  image_url       text,
  linked_book_id  uuid references public.books(id),
  external_link   text,
  order_index     int  not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

comment on column public.home_banners.linked_book_id is 'لينك لكتاب معيّن (اختياري)';
comment on column public.home_banners.external_link  is 'لينك خارجي مثل بث مباشر (اختياري)';

-- ============================================================
-- SECTION 3: BASE FUNCTIONS
-- Created AFTER the tables: is_admin() is LANGUAGE sql and its body
-- is validated at CREATE time, so public.users must already exist.
-- The plpgsql functions (set_updated_at, handle_new_user,
-- rls_auto_enable) are not body-validated at creation, but are grouped
-- here for clarity.  They are referenced by the triggers (Section 4/6)
-- and policies (Section 8) that follow.
-- ============================================================

-- -----------------------------------------------------------
-- 3a. set_updated_at() — BEFORE UPDATE trigger function.
--     Reused by books, lessons, lesson_progress, users,
--     final_exam_settings, and (later) generation_jobs,
--     lesson_notes, suggestion_notes.
-- -----------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- -----------------------------------------------------------
-- 3b. is_admin() — used in every RLS policy that gates admin.
--     SECURITY DEFINER so it can read public.users without
--     triggering the users RLS policy recursion.
--     LANGUAGE sql → body validated at CREATE time, which is why
--     public.users (Section 2) must already exist.
--     No set search_path — matches the live DB definition.
-- -----------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$;

-- -----------------------------------------------------------
-- 3c. handle_new_user() — original pre-guest-mode body.
--     Assumes new.email is non-null (real sign-ups only).
--     Replaced by migration 0005_guest_mode.sql which adds
--     anonymous-user support (guest placeholder email, etc.).
-- -----------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.users (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    new.email,
    'student'
  );
  return new;
end;
$$;

-- -----------------------------------------------------------
-- 3d. rls_auto_enable() — event trigger function.
--     Present in the live DB; auto-enables RLS on any newly
--     created table in the public schema.  The matching
--     CREATE EVENT TRIGGER is a cluster-level object and is
--     NOT emitted by pg_dump --schema public, so it cannot be
--     reproduced here from the dump alone.  Since every
--     migration that creates a table also calls
--     ALTER TABLE … ENABLE ROW LEVEL SECURITY explicitly, the
--     absence of the event trigger does NOT affect a fresh
--     install from migrations.
-- -----------------------------------------------------------
create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  cmd record;
begin
  for cmd in
    select *
    from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      and object_type in ('table', 'partitioned table')
  loop
    if cmd.schema_name is not null
       and cmd.schema_name in ('public')
       and cmd.schema_name not in ('pg_catalog', 'information_schema')
       and cmd.schema_name not like 'pg_toast%'
       and cmd.schema_name not like 'pg_temp%'
    then
      begin
        execute format('alter table if exists %s enable row level security',
                       cmd.object_identity);
        raise log 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      exception
        when others then
          raise log 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      end;
    else
      raise log 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)',
                cmd.object_identity, cmd.schema_name;
    end if;
  end loop;
end;
$$;

-- ============================================================
-- SECTION 4: TRIGGER ON auth.users
-- Fires after every new auth sign-up and creates a public.users
-- profile row.  Migration 0005 replaces handle_new_user() to
-- support anonymous sign-ins; the trigger itself is not recreated
-- (0005 comment: "the on_auth_user_created trigger already exists").
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- SECTION 5: INDEXES ON BASE TABLES
-- Only indexes on tables defined in this file.  Tables created
-- by later migrations add their own indexes in those files.
-- ============================================================

create index if not exists idx_books_section
  on public.books(section_id);

create index if not exists idx_books_featured
  on public.books(is_featured, featured_order)
  where is_featured = true;

create index if not exists idx_lessons_book
  on public.lessons(book_id, order_index);

create index if not exists idx_enrollments_user
  on public.enrollments(user_id);

create index if not exists idx_enrollments_book
  on public.enrollments(book_id);

create index if not exists idx_quiz_lesson
  on public.lesson_quiz_questions(lesson_id);

create index if not exists idx_progress_user
  on public.lesson_progress(user_id);

create index if not exists idx_progress_lesson
  on public.lesson_progress(lesson_id);

create index if not exists idx_final_exam_q_book
  on public.final_exam_questions(book_id, order_index);

create index if not exists idx_attempts_user_book
  on public.final_exam_attempts(user_id, book_id);

create index if not exists idx_certificates_user
  on public.certificates(user_id);

create index if not exists idx_questions_book
  on public.student_questions(book_id);

create index if not exists idx_questions_lesson
  on public.student_questions(lesson_id);

create index if not exists idx_questions_status
  on public.student_questions(status);

create index if not exists idx_banners_active
  on public.home_banners(is_active, order_index);

-- ============================================================
-- SECTION 6: BEFORE UPDATE TRIGGERS ON BASE TABLES
-- Use the shared set_updated_at() function.
-- ============================================================

create trigger trg_books_updated_at
  before update on public.books
  for each row execute function public.set_updated_at();

create trigger trg_lessons_updated_at
  before update on public.lessons
  for each row execute function public.set_updated_at();

create trigger trg_progress_updated_at
  before update on public.lesson_progress
  for each row execute function public.set_updated_at();

create trigger trg_exam_settings_updated_at
  before update on public.final_exam_settings
  for each row execute function public.set_updated_at();

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ============================================================
-- SECTION 7: ROW LEVEL SECURITY — ENABLE ON BASE TABLES
-- ============================================================

alter table public.users               enable row level security;
alter table public.sections            enable row level security;
alter table public.books               enable row level security;
alter table public.lessons             enable row level security;
alter table public.enrollments         enable row level security;
alter table public.lesson_quiz_questions enable row level security;
alter table public.lesson_quiz_attempts  enable row level security;
alter table public.final_exam_settings   enable row level security;
alter table public.final_exam_questions  enable row level security;
alter table public.final_exam_attempts   enable row level security;
alter table public.certificates          enable row level security;
alter table public.lesson_progress       enable row level security;
alter table public.notifications         enable row level security;
alter table public.notification_reads    enable row level security;
alter table public.student_questions     enable row level security;
alter table public.home_banners          enable row level security;

-- ============================================================
-- SECTION 8: BASE RLS POLICIES
--
-- These are the policies that existed BEFORE the numbered
-- migration stack.  Many are subsequently modified:
--   • 0003 adds  questions_select_own
--   • 0005 adds  not is_guest() guards to multiple own-data policies
--   • 0006 replaces notifications_select_all with notifications_select_scoped
--   • 0007 replaces lessons_select_published_or_admin with
--          lessons_select_entitled (via can_read_lesson helper)
--   • 0010 adds  questions_admin_delete
-- ============================================================

-- ---- users ----
create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);

create policy "users_select_own_or_admin" on public.users
  for select using (auth.uid() = id or public.is_admin());

-- users_update_own: 0005 adds `and not public.is_guest()`
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- ---- sections ----
create policy "sections_select_all" on public.sections
  for select using (true);

create policy "sections_admin_write" on public.sections
  using (public.is_admin()) with check (public.is_admin());

-- ---- books ----
create policy "books_select_published_or_admin" on public.books
  for select using (status = 'published' or public.is_admin());

create policy "books_admin_write" on public.books
  using (public.is_admin()) with check (public.is_admin());

-- ---- lessons ----
-- Replaced by 0007_lesson_entitlement_fix.sql with "lessons_select_entitled"
-- (uses the can_read_lesson() SECURITY DEFINER helper to avoid policy recursion).
create policy "lessons_select_published_or_admin" on public.lessons
  for select using (public.is_admin() or status = 'published');

create policy "lessons_admin_write" on public.lessons
  using (public.is_admin()) with check (public.is_admin());

-- ---- enrollments ----
-- 0005 adds `and not public.is_guest()` to both policies below.
create policy "enrollments_insert_own" on public.enrollments
  for insert with check (auth.uid() = user_id);

create policy "enrollments_select_own_or_admin" on public.enrollments
  for select using (auth.uid() = user_id or public.is_admin());

-- ---- lesson_quiz_questions ----
create policy "quiz_admin_write" on public.lesson_quiz_questions
  using (public.is_admin()) with check (public.is_admin());

create policy "quiz_select_admin" on public.lesson_quiz_questions
  for select using (public.is_admin());

-- ---- lesson_quiz_attempts ----
-- All client inserts blocked; writes go through submit_lesson_quiz RPC only.
create policy "quiz_attempts_no_direct_insert" on public.lesson_quiz_attempts
  for insert with check (false);

create policy "quiz_attempts_student_select" on public.lesson_quiz_attempts
  for select using (auth.uid() = user_id or public.is_admin());

-- ---- final_exam_settings ----
create policy "exam_settings_select_all" on public.final_exam_settings
  for select using (true);

create policy "exam_settings_admin_write" on public.final_exam_settings
  using (public.is_admin()) with check (public.is_admin());

-- ---- final_exam_questions ----
create policy "final_exam_q_select_admin" on public.final_exam_questions
  for select using (public.is_admin());

create policy "final_exam_q_admin_write" on public.final_exam_questions
  using (public.is_admin()) with check (public.is_admin());

-- ---- final_exam_attempts ----
-- 0005 adds `and not public.is_guest()` to both policies below.
create policy "attempts_insert_own" on public.final_exam_attempts
  for insert with check (auth.uid() = user_id);

create policy "attempts_select_own_or_admin" on public.final_exam_attempts
  for select using (auth.uid() = user_id or public.is_admin());

-- ---- certificates ----
-- 0005 adds `and not public.is_guest()` to this policy.
create policy "certificates_select_own_or_admin" on public.certificates
  for select using (auth.uid() = user_id or public.is_admin());

-- ---- lesson_progress ----
-- 0005 adds `and not public.is_guest()` to both policies below.
create policy "progress_upsert_own" on public.lesson_progress
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "progress_select_own_or_admin" on public.lesson_progress
  for select using (auth.uid() = user_id or public.is_admin());

-- ---- notifications ----
-- 0006 drops this policy and creates "notifications_select_scoped" which
-- also gates on target_user_id (the new column it adds).
create policy "notifications_select_all" on public.notifications
  for select using (true);

create policy "notifications_admin_write" on public.notifications
  using (public.is_admin()) with check (public.is_admin());

-- ---- notification_reads ----
-- 0005 adds `and not public.is_guest()` to both policies below.
create policy "notif_reads_insert_own" on public.notification_reads
  for insert with check (auth.uid() = user_id);

create policy "notif_reads_select_own" on public.notification_reads
  for select using (auth.uid() = user_id);

-- ---- student_questions ----
-- questions_select_own is NOT here — it is added by 0003_student_questions_select_own.
-- questions_admin_delete is NOT here — it is added by 0010.
-- 0005 adds `and not public.is_guest()` to questions_insert_own.
create policy "questions_insert_own" on public.student_questions
  for insert with check (auth.uid() = user_id);

create policy "questions_select_admin" on public.student_questions
  for select using (public.is_admin());

create policy "questions_admin_update" on public.student_questions
  for update using (public.is_admin()) with check (public.is_admin());

-- ---- home_banners ----
create policy "banners_select_active_or_admin" on public.home_banners
  for select using (is_active = true or public.is_admin());

create policy "banners_admin_write" on public.home_banners
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- RECONCILIATION NOTES — Differences between
-- "baseline + 0001–0023" and the live pg_dump that cannot be
-- fully resolved from the available files:
--
-- [R1] rls_auto_enable() EVENT TRIGGER:
--      The function is created above.  The companion
--      CREATE EVENT TRIGGER ... ON ddl_command_end ... is a
--      cluster-level object and is NOT included in a
--      --schema public dump.  Whether it is active on the live
--      project is unknown.  Since every migration explicitly
--      calls ALTER TABLE ... ENABLE ROW LEVEL SECURITY, the
--      event trigger is not required for a fresh install.
--
-- [R2] 0001_app_support.sql was truncated in the repo (recovery
--      audit).  Restored on branch fix/missing-definitions from
--      the verbatim rollback block in 0005_guest_mode.sql.  The
--      5 assessment RPCs are also recreated by 0005/0006/0014 and
--      the student_questions_public view by 0002_qa_fixes.sql, so
--      the fresh-install result matches the live schema.
--
-- [R3] 0006b_notification_scoping.sql is also truncated (2 lines).
--      Its header says it "runs on top of 0001 → 0005".  Based
--      on naming it appears to be a duplicate of
--      0006_notification_scoping.sql.  The live schema already
--      matches 0006's final state.
--
-- [R4] sync_lesson_pdf_url() in the live dump has
--      SET search_path TO '' while 0012 defines it with
--      SET search_path TO public, pg_catalog.  This is likely
--      a Supabase normalization artifact when search_path
--      contains only fully-qualified names; functionally
--      equivalent.
--
-- [R5] on_auth_user_created and on_auth_user_converted triggers
--      are on auth.users (a non-public schema) and therefore
--      are NOT emitted by pg_dump --schema public.  Both are
--      created/updated in the migration stack
--      (baseline → 0005_guest_mode.sql).
--
-- [R6] WHITELABEL.md Step 10 references `set is_admin = true`
--      which was a pre-existing documentation bug — the column
--      is named `role` (a user_role enum), not `is_admin`.
--      The correct statement is:
--        update public.users set role = 'admin' where email = '…';
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0001_app_support.sql
-- ============================================================
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

-- ============================================================
-- SOURCE: supabase/migrations/0002_hardening.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Phase 8 Hardening Migration 0002_hardening.sql
-- Additive only — runs on top of 0001_app_support.sql.
-- Run once in Supabase SQL Editor.
-- ============================================================

-- ============================================================
-- CC-5: Transactional lesson reorder RPC
-- Wraps all order_index updates in a single transaction so a
-- network failure cannot leave order_index partially updated.
-- ============================================================

create or replace function public.reorder_lessons(
  p_updates jsonb  -- [{"id": "<uuid>", "order_index": <int>}, ...]
) returns void
language plpgsql
security invoker   -- admin RLS UPDATE policy already applies
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.lessons
    set    order_index = (v_row->>'order_index')::int,
           updated_at  = now()
    where  id = (v_row->>'id')::uuid;
  end loop;
  -- If any row update fails the whole function call rolls back.
end;
$$;

-- Grant execute to authenticated users; RLS on the underlying table
-- already restricts non-admins from updating lessons.
grant execute on function public.reorder_lessons(jsonb) to authenticated;

-- ============================================================
-- CC-25: Featured-books cap — auto-drop lowest-priority book
-- When a 6th book is featured the one with the highest
-- featured_order (= lowest display priority) is automatically
-- unfeatured so the cap of 5 is never permanently exceeded.
-- ============================================================

create or replace function public.enforce_featured_cap()
returns trigger
language plpgsql
security definer
as $$
declare
  v_count int;
begin
  if NEW.is_featured = true then
    select count(*) into v_count
    from   public.books
    where  is_featured = true;

    if v_count > 5 then
      -- Unfeature the book with the highest featured_order (lowest priority)
      -- that is not the book just featured.
      update public.books
      set    is_featured    = false,
             featured_order = null
      where  id = (
        select id
        from   public.books
        where  is_featured = true
          and  id <> NEW.id
        order  by coalesce(featured_order, 2147483647) desc
        limit  1
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_featured_cap on public.books;
create trigger trg_featured_cap
  after insert or update of is_featured on public.books
  for each row
  execute function public.enforce_featured_cap();

-- ============================================================
-- SOURCE: supabase/migrations/0002_qa_fixes.sql
-- ============================================================
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

-- ============================================================
-- SKIPPED: supabase/migrations/0002b_qa_fixes.sql
--   Reason: duplicate of 0002_qa_fixes.sql — identical content; skipped to avoid re-applying
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0003_student_questions_select_own.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0003_student_questions_select_own.sql
-- Additive only — runs on top of 0002_hardening.sql.
-- Run once in Supabase SQL Editor.
-- ============================================================

-- Fix: the "أسئلتي" (My Questions) screen was empty because
-- 0001_app_support.sql left student_questions with an admin-only
-- SELECT policy. Allow a student to read THEIR OWN questions.
-- CC-22-safe: only own rows (auth.uid() = user_id) are exposed;
-- other students' rows stay unreadable on the base table, and the
-- public feed still goes through student_questions_public (no user_id).

drop policy if exists "questions_select_own" on public.student_questions;
create policy "questions_select_own" on public.student_questions
  for select using (auth.uid() = user_id);

-- ============================================================
-- SOURCE: supabase/migrations/0004_onboarding.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Companion Migration 0004_onboarding.sql
-- Additive only — runs on top of the base schema.sql + 0001–0003.
-- Run this ONCE in Supabase SQL Editor.
-- Adds the admin-managed onboarding slides table shown before login.
-- ============================================================

create table public.onboarding_slides (
  id          uuid primary key default gen_random_uuid(),
  order_index int  not null,
  type        text not null check (type in ('hadith', 'normal')),
  main_text   text not null,  -- الحديث أو العنوان
  sub_text    text,           -- النص التوضيحي (اختياري)
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.onboarding_slides enable row level security;

-- Anyone can read active slides; admin can read all (incl. inactive).
create policy "onboarding_read_all" on public.onboarding_slides
  for select using (is_active = true or public.is_admin());

-- Only admin can insert/update/delete.
create policy "onboarding_admin_write" on public.onboarding_slides
  for all using (public.is_admin());

-- Seed initial data.
insert into public.onboarding_slides (order_index, type, main_text, sub_text) values
(1, 'hadith', 'مَن يُرِدِ اللهُ بِهِ خَيْرًا يُفَقِّهْهُ في الدِّينِ', 'شيخي — طريقك لطلب العلم الشرعي'),
(2, 'normal', 'تعلّم من المتون والكتب', 'دروس مرئية ومسموعة وكتب أصيلة بإشراف أهل العلم'),
(3, 'normal', 'ابدأ رحلتك في طلب العلم', 'اختبارات وشهادات إتمام تُرافقك في مسيرتك');

-- ===== END OF PART 1 / START OF PART 2 =====

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

-- ===== END OF PART 2 / START OF PART 3 =====

-- ============================================================
-- SOURCE: supabase/migrations/0009_split_media_position.sql
-- ============================================================
-- 0009_split_media_position.sql
-- Additive migration: split lesson resume position into per-medium columns.
--
-- Previously video and audio shared lesson_progress.last_position_seconds, so the
-- audio position-save timer overwrote the video resume point and vice-versa. Give
-- each medium its own column. last_position_seconds is kept (dormant) for now — a
-- later cleanup can drop it once no reads remain.

alter table lesson_progress
  add column if not exists video_position_seconds int not null default 0,
  add column if not exists audio_position_seconds int not null default 0;

-- Backfill: existing saved positions are assumed to be video positions.
update lesson_progress
  set video_position_seconds = last_position_seconds
  where last_position_seconds > 0;

-- ============================================================
-- SOURCE: supabase/migrations/0010_student_questions_admin_delete.sql
-- ============================================================
-- 0010_student_questions_admin_delete.sql
-- Additive-only. Adds admin-only DELETE on student_questions so the admin can
-- delete individual questions and clear all questions for a book.
-- The base schema only defined select/insert/admin-update policies.

drop policy if exists "questions_admin_delete" on public.student_questions;
create policy "questions_admin_delete" on public.student_questions
  for delete using (public.is_admin());

-- ============================================================
-- SOURCE: supabase/migrations/0011_ai_question_generation.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Companion Migration 0011_ai_question_generation.sql
-- Additive only — runs on top of 0001–0010.
-- Run this ONCE in Supabase SQL Editor.
--
-- Adds the database layer for AI-assisted quiz-question generation:
--   1. Extends lesson_quiz_questions with provenance + review columns.
--   2. Extends lessons with transcript pipeline columns.
--   3. Creates generation_jobs table (admin-only, RLS-guarded).
--   4. Replaces lesson_quiz_questions_student view to filter out
--      questions still under AI review (ai_review_status != 'approved').
--
-- Safe defaults: existing rows get source='manual',
-- ai_review_status='approved' — zero behavior change for current data.
-- Does NOT touch final_exam_questions (deferred).
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Extend lesson_quiz_questions
-- ────────────────────────────────────────────────────────────

alter table public.lesson_quiz_questions
  add column if not exists source text not null default 'manual'
    check (source in ('manual', 'ai_generated', 'edited_by_admin')),

  add column if not exists ai_review_status text not null default 'approved'
    check (ai_review_status in ('pending', 'approved', 'rejected')),

  -- Optional metadata columns (nullable, no behavioral impact on existing rows)
  add column if not exists difficulty text
    check (difficulty in ('easy', 'medium', 'hard')),

  add column if not exists explanation text,

  add column if not exists source_quote text,

  add column if not exists reviewed_by uuid
    references public.users(id),

  add column if not exists reviewed_at timestamptz;

-- ────────────────────────────────────────────────────────────
-- 2. Extend lessons with transcript pipeline columns
-- ────────────────────────────────────────────────────────────

alter table public.lessons
  add column if not exists transcript text,

  add column if not exists transcript_status text not null default 'none'
    check (transcript_status in ('none', 'queued', 'running', 'ready', 'failed')),

  add column if not exists transcript_error text,

  add column if not exists transcript_generated_at timestamptz;

-- ────────────────────────────────────────────────────────────
-- 3. generation_jobs — tracks transcribe + generate_questions jobs
-- ────────────────────────────────────────────────────────────

create table if not exists public.generation_jobs (
  id              uuid        primary key default gen_random_uuid(),
  lesson_id       uuid        not null references public.lessons(id) on delete cascade,
  job_type        text        not null check (job_type in ('transcribe', 'generate_questions')),
  status          text        not null default 'queued'
                              check (status in ('queued', 'running', 'done', 'failed')),
  requested_count int,
  difficulty_mix  jsonb,
  result_count    int,
  error_message   text,
  created_by      uuid        references public.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.generation_jobs enable row level security;

-- Admin can do everything; no student visibility at all.
create policy "generation_jobs_admin_all" on public.generation_jobs
  for all using (public.is_admin()) with check (public.is_admin());

-- Auto-stamp updated_at on every update (reuses the shared function from schema.sql).
create trigger trg_generation_jobs_updated_at
  before update on public.generation_jobs
  for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────
-- 4. Replace lesson_quiz_questions_student view
--    Identical to the 0005 definition + one extra condition:
--    q.ai_review_status = 'approved'
--    Existing rows default to 'approved' so no data is hidden.
-- ────────────────────────────────────────────────────────────

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
  and q.ai_review_status = 'approved';

-- Re-apply the existing grant (create or replace resets it).
grant select on public.lesson_quiz_questions_student to authenticated;

-- ============================================================
-- Rollback (run manually if needed — migrations are never auto-rolled back)
--
-- drop view if exists public.lesson_quiz_questions_student;
-- (then re-apply the 0005 definition without the ai_review_status clause)
--
-- drop trigger if exists trg_generation_jobs_updated_at on public.generation_jobs;
-- drop table if exists public.generation_jobs;
--
-- alter table public.lessons
--   drop column if exists transcript,
--   drop column if exists transcript_status,
--   drop column if exists transcript_error,
--   drop column if exists transcript_generated_at;
--
-- alter table public.lesson_quiz_questions
--   drop column if exists source,
--   drop column if exists ai_review_status,
--   drop column if exists difficulty,
--   drop column if exists explanation,
--   drop column if exists source_quote,
--   drop column if exists reviewed_by,
--   drop column if exists reviewed_at;
-- ============================================================

-- ============================================================
-- SKIPPED: supabase/migrations/0011_test_harness.sql
--   Reason: BEGIN…ROLLBACK test script — produces no permanent state; skipped
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0012_lesson_pdfs.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0012_lesson_pdfs.sql   (Multiple PDFs per lesson)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: replace the single lessons.pdf_url with a proper child table so a
-- lesson can carry several titled PDFs (transcript, the book itself, handouts…).
-- Mirrors the existing lesson_quiz_questions pattern: a per-lesson child table
-- with its own RLS (students read published+entitled content, admin writes).
--
-- lessons.pdf_url is KEPT as a DEPRECATED compatibility shim for legacy app
-- builds. It is maintained solely by the trigger below (auto-mirror of the first
-- lesson_pdfs row). The app never writes it again.
--
-- ── Why NO unique(lesson_id, order_index) ──────────────────
-- The app reorders PDFs with one UPDATE per row via the Supabase client — each
-- is a separate transaction. A unique constraint (even DEFERRABLE INITIALLY
-- DEFERRED, which only defers to *that* transaction's commit) would collide
-- mid-sequence. Uniqueness is instead kept app-side by contiguous renumbering on
-- reorder (same approach as reorderLessons). A plain index is enough.
--
-- ── Why the mirror is a TRIGGER, not app code ──────────────
-- PDFs are saved via immediate per-row CRUD, not one atomic "save". Computing the
-- mirror in the Dart save handler would miss adds/deletes the admin never "saves"
-- and could leave pdf_url pointing at a deleted file. The trigger fires on every
-- insert/update/delete and stays correct (nulls out when the last PDF is gone).
-- SECURITY DEFINER lets the function UPDATE public.lessons even though the caller
-- (admin) has no direct grant path that RLS would otherwise satisfy; the WRITE
-- GATE stays the lesson_pdfs admin-write policy — a student is rejected there and
-- never reaches the trigger. search_path is pinned (injection hardening).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Child table (no unique constraint — plain index only)
-- ------------------------------------------------------------
create table if not exists public.lesson_pdfs (
  id          uuid primary key default uuid_generate_v4(),
  lesson_id   uuid not null references public.lessons(id) on delete cascade,
  title       text not null,
  url         text not null,
  order_index int  not null default 0,
  created_at  timestamptz not null default now()
);

comment on table public.lesson_pdfs is
  'ملفات PDF المتعددة لكل درس (النص، الكتاب، مرفقات). ترتيبها order_index.';

create index if not exists idx_lesson_pdfs_lesson
  on public.lesson_pdfs(lesson_id, order_index);

alter table public.lesson_pdfs enable row level security;

-- ------------------------------------------------------------
-- 2. RLS — mirror the lessons entitlement pattern.
--    SELECT: admin, or the parent lesson is published AND the caller is
--            entitled to it (can_read_lesson bypasses RLS internally → no
--            recursion, same mechanism as the lessons policy in 0007).
--    WRITE:  admin only (this is the security gate for the mirror trigger).
-- ------------------------------------------------------------
drop policy if exists "lesson_pdfs_select_entitled" on public.lesson_pdfs;
create policy "lesson_pdfs_select_entitled" on public.lesson_pdfs
for select using (
  public.is_admin()
  or exists (
    select 1 from public.lessons l
    where l.id = lesson_pdfs.lesson_id
      and l.status = 'published'
      and public.can_read_lesson(l.id, l.book_id)
  )
);

drop policy if exists "lesson_pdfs_admin_write" on public.lesson_pdfs;
create policy "lesson_pdfs_admin_write" on public.lesson_pdfs
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 3. Auto-mirror trigger: keep lessons.pdf_url = first lesson_pdfs row.
--    Runs AFTER every row change; nulls pdf_url when the last PDF is deleted.
--    SECURITY DEFINER (owner) so it can UPDATE public.lessons regardless of the
--    caller; the lesson_pdfs admin-write policy is the real gate.
-- ------------------------------------------------------------
create or replace function public.sync_lesson_pdf_url()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  -- Refresh the affected lesson(s). NEW/OLD lesson_id differ only if a PDF is
  -- ever re-parented; refresh both, skipping nulls and the duplicate.
  if (tg_op <> 'DELETE' and new.lesson_id is not null) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = new.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = new.lesson_id;
  end if;

  if (tg_op <> 'INSERT' and old.lesson_id is not null
      and old.lesson_id is distinct from
          (case when tg_op <> 'DELETE' then new.lesson_id end)) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = old.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = old.lesson_id;
  end if;

  return null; -- AFTER trigger: return value ignored
end;
$$;

drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
create trigger trg_sync_lesson_pdf_url
  after insert or update or delete on public.lesson_pdfs
  for each row execute function public.sync_lesson_pdf_url();

comment on column public.lessons.pdf_url is
  'DEPRECATED — auto-mirror of the first lesson_pdfs row (maintained by trigger '
  'sync_lesson_pdf_url), for legacy app builds only. Never written by the app.';

-- ------------------------------------------------------------
-- 4. Backfill: one PDF row per lesson that currently has a pdf_url.
--    (The trigger will re-affirm the same mirror value — harmless.)
-- ------------------------------------------------------------
insert into public.lesson_pdfs (lesson_id, title, url, order_index)
select id, 'ملف PDF', pdf_url, 0
from public.lessons
where pdf_url is not null
  and not exists (
    select 1 from public.lesson_pdfs p where p.lesson_id = public.lessons.id
  );

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
drop function if exists public.sync_lesson_pdf_url();
drop table if exists public.lesson_pdfs;   -- removes rows + policies
-- (lessons.pdf_url values remain as they were last mirrored)
*/

-- ============================================================
-- ✅ TEST HARNESS — run FIRST, verbatim, in the SQL Editor. Wrapped in a
-- transaction that ROLLS BACK, so nothing persists. Verifies:
--   (A) no 42P17 recursion when a real authenticated user selects lesson_pdfs;
--   (B) the SELECT policy hides other lessons' PDFs from a non-entitled user;
--   (C) SECURITY DEFINER lets the trigger update lessons.pdf_url, and the mirror
--       tracks insert / reorder / delete-last correctly;
--   (D) a NON-ADMIN authenticated user is REJECTED by the write policy and thus
--       can never fire the trigger (no privilege escalation via the mirror).
--
-- Replace <ADMIN_UUID>, <STUDENT_UUID>, <LESSON_UUID> (a published lesson) below.
-- ============================================================
/*
begin;

-- ---- (A)+(C) as ADMIN: writes allowed, trigger mirrors pdf_url --------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<ADMIN_UUID>","role":"authenticated","is_anonymous":false}';

-- insert two PDFs; after this, lessons.pdf_url should equal the order_index=0 url
insert into public.lesson_pdfs (lesson_id, title, url, order_index) values
  ('<LESSON_UUID>', 'الأول', 'https://drive.google.com/file/d/AAA/view', 0),
  ('<LESSON_UUID>', 'الثاني','https://drive.google.com/file/d/BBB/view', 1);
select pdf_url as after_insert_should_be_AAA
  from public.lessons where id = '<LESSON_UUID>';

-- reorder: make BBB first → mirror should become BBB
update public.lesson_pdfs set order_index = 0
  where lesson_id = '<LESSON_UUID>' and title = 'الثاني';
update public.lesson_pdfs set order_index = 1
  where lesson_id = '<LESSON_UUID>' and title = 'الأول';
select pdf_url as after_reorder_should_be_BBB
  from public.lessons where id = '<LESSON_UUID>';

-- delete all → mirror should become NULL
delete from public.lesson_pdfs where lesson_id = '<LESSON_UUID>';
select pdf_url as after_delete_should_be_null
  from public.lessons where id = '<LESSON_UUID>';

reset role;

-- ---- (D) as NON-ADMIN student: write MUST be rejected by RLS ----------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<STUDENT_UUID>","role":"authenticated","is_anonymous":false}';

-- Expected: ERROR new row violates row-level security policy for "lesson_pdfs".
-- (If this SUCCEEDS, the write gate is broken — do NOT ship.)
do $$
begin
  insert into public.lesson_pdfs (lesson_id, title, url, order_index)
  values ('<LESSON_UUID>', 'اختراق', 'https://x', 0);
  raise exception 'SECURITY FAIL: student insert into lesson_pdfs succeeded';
exception
  when insufficient_privilege or others then
    raise notice 'OK: student insert rejected (%).', sqlerrm;
end $$;

-- (A)+(B) student SELECT must not raise 42P17 and only sees entitled rows:
select count(*) as visible_pdf_rows from public.lesson_pdfs;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0012_lesson_pdfs.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0013_lesson_notes.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0013_lesson_notes.sql   (Student lecture notes)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: let a student attach a short plain-text note to a specific second of
-- a lecture video, and browse their notes per book. book_id is STORED (not just
-- derivable) so "all my notes in this book" is a single indexed query with no
-- join to lessons. Strictly owner-only (private notes).
-- ============================================================

create table if not exists public.lesson_notes (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id)   on delete cascade,
  lesson_id        uuid not null references public.lessons(id) on delete cascade,
  book_id          uuid not null references public.books(id)   on delete cascade,
  note_text        text not null check (char_length(btrim(note_text)) between 1 and 1000),
  position_seconds int  not null default 0 check (position_seconds >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.lesson_notes is
  'ملحوظات الطالب النصية المرتبطة بلحظة زمنية في فيديو المحاضرة.';

create index if not exists idx_lesson_notes_user_book
  on public.lesson_notes(user_id, book_id);
create index if not exists idx_lesson_notes_user_lesson
  on public.lesson_notes(user_id, lesson_id, position_seconds);

alter table public.lesson_notes enable row level security;

-- Table privileges (RLS narrows these row-by-row).
grant select, insert, update, delete on public.lesson_notes to authenticated;

-- RLS — strictly owner-only for every operation.
drop policy if exists "lesson_notes_select_own" on public.lesson_notes;
create policy "lesson_notes_select_own" on public.lesson_notes
  for select using (auth.uid() = user_id);

drop policy if exists "lesson_notes_insert_own" on public.lesson_notes;
create policy "lesson_notes_insert_own" on public.lesson_notes
  for insert with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_update_own" on public.lesson_notes;
create policy "lesson_notes_update_own" on public.lesson_notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_delete_own" on public.lesson_notes;
create policy "lesson_notes_delete_own" on public.lesson_notes
  for delete using (auth.uid() = user_id);

-- Auto-maintain updated_at (existing shared function).
drop trigger if exists trg_lesson_notes_updated_at on public.lesson_notes;
create trigger trg_lesson_notes_updated_at before update on public.lesson_notes
  for each row execute function public.set_updated_at();

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop table if exists public.lesson_notes;   -- removes rows, indexes, policies, trigger
*/

-- ============================================================
-- TEST HARNESS — run AFTER applying the migration above, as a SECOND query.
-- Wrapped in a transaction that ROLLS BACK, so nothing persists.
-- Verifies (as the AUTHENTICATED role, not postgres):
--   (A) an authenticated user can insert + select their OWN note;
--   (B) a SECOND authenticated user CANNOT see the first user's note (owner-only).
--
-- Replace <USER_A_UUID> and <USER_B_UUID> (two distinct real users) and
-- <LESSON_UUID> / <BOOK_UUID> (a lesson and its book) below.
-- Expected: after_insert = 1, then user B sees 0, then 'OK: owner-only verified'.
-- ============================================================
/*
begin;

-- ---- (A) as USER A: insert + select own note --------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_A_UUID>","role":"authenticated","is_anonymous":false}';

insert into public.lesson_notes (user_id, lesson_id, book_id, note_text, position_seconds)
values ('<USER_A_UUID>', '<LESSON_UUID>', '<BOOK_UUID>', 'ملحوظة تجريبية', 125);

select count(*) as after_insert_should_be_1
  from public.lesson_notes where user_id = '<USER_A_UUID>';

reset role;

-- ---- (B) as USER B: must NOT see USER A's note ------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_B_UUID>","role":"authenticated","is_anonymous":false}';

do $$
declare v int;
begin
  select count(*) into v from public.lesson_notes;
  if v <> 0 then
    raise exception 'SECURITY FAIL: user B can see % note(s) that are not theirs', v;
  end if;
  raise notice 'OK: owner-only verified (user B sees 0 notes).';
end $$;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0013_lesson_notes.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0014_quiz_entitlement.sql
-- ============================================================
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

-- ============================================================
-- SOURCE: supabase/migrations/0015_lesson_duration.sql
-- ============================================================
-- 0015_lesson_duration.sql
-- Additive migration: manual per-medium lesson durations + study-seconds RPC.
--
-- Study hours on the Achievements card were a flat 15-min-per-completed-lesson
-- estimate, which heavily under-counts long lessons. Durations are now entered
-- MANUALLY by the admin, separately for video and audio, in minutes. Students
-- never write to `lessons`. Study seconds are computed server-side from real
-- durations (completed lessons) and saved positions (in-progress lessons).

alter table public.lessons
  add column if not exists video_duration_minutes int null
    check (video_duration_minutes between 1 and 600),
  add column if not exists audio_duration_minutes int null
    check (audio_duration_minutes between 1 and 600);

comment on column public.lessons.video_duration_minutes is
  'مدة الفيديو بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';
comment on column public.lessons.audio_duration_minutes is
  'مدة الملف الصوتي بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';

-- ------------------------------------------------------------
-- get_my_study_seconds() — total study seconds for the current user.
-- SECURITY DEFINER so it can read lessons.*_duration_minutes regardless of the
-- caller's row-level access; scoped to auth.uid() so a user only ever sees own.
--
-- Per lesson_progress row (vp = video position, ap = audio position, both >= 0):
--   completed = true  → the primary medium's duration (the one with the larger
--                       saved position) in seconds, falling back to the other
--                       medium's duration, then to greatest(vp, ap) if non-zero,
--                       then to a 900s (15 min) constant.
--   completed = false → greatest(vp, ap), capped at the relevant medium's
--                       duration in seconds when that duration is known.
-- ------------------------------------------------------------
create or replace function public.get_my_study_seconds()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    case
      when lp.completed then
        coalesce(
          -- primary medium = the one the student engaged with more
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.audio_duration_minutes * 60
               else l.video_duration_minutes * 60
          end,
          -- fall back to the other medium's known duration
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.video_duration_minutes * 60
               else l.audio_duration_minutes * 60
          end,
          -- then to whatever position we managed to save
          nullif(greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)), 0),
          -- last-resort constant so completed lessons never count as zero
          900
        )
      else
        -- in-progress: real elapsed position, capped at the known duration.
        -- The cap uses the primary medium's duration (larger saved position),
        -- falling back to the other medium's duration — so an audio-only lesson
        -- still caps against audio when positions tie (video duration is null).
        case
          when coalesce(
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.audio_duration_minutes else l.video_duration_minutes end,
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.video_duration_minutes else l.audio_duration_minutes end
               ) is not null
          then least(
                 greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)),
                 coalesce(
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.audio_duration_minutes else l.video_duration_minutes end,
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.video_duration_minutes else l.audio_duration_minutes end
                 ) * 60)
          else greatest(coalesce(lp.video_position_seconds, 0),
                        coalesce(lp.audio_position_seconds, 0))
        end
    end
  ), 0)::bigint
  from public.lesson_progress lp
  join public.lessons l on l.id = lp.lesson_id
  where lp.user_id = auth.uid();
$$;

grant execute on function public.get_my_study_seconds() to authenticated;

-- ============================================================
-- SOURCE: supabase/migrations/0016_lessons_public_duration.sql
-- ============================================================
-- 0016_lessons_public_duration.sql
-- Additive: expose the admin-entered per-medium durations (migration 0015) to
-- the student-facing lesson list, which reads the URL-free `lessons_public`
-- view (0006 → 0008). Both columns are plain metadata (minutes, nullable) — no
-- URLs or quiz content — so surfacing them keeps the view's guest-safe contract.
--
-- Full `create or replace view` that re-states 0008's definition and appends
-- video_duration_minutes / audio_duration_minutes. security_invoker = false is
-- preserved so the view keeps running as owner (unchanged behaviour).

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
   ))                                        as has_quiz,
  video_duration_minutes,
  audio_duration_minutes
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;

-- ===== END OF PART 3 / START OF PART 4 =====

-- ============================================================
-- SOURCE: supabase/migrations/0017_suggestions.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Companion Migration 0017_suggestions.sql
-- Additive only — runs on top of the base schema.sql + 0001–0016.
-- Run this ONCE in Supabase SQL Editor.
-- Adds the admin-managed "مقترحات" (suggestions) home slider: curated
-- video (YouTube) / audio (Google Drive) media cards shown to students.
-- RLS mirrors onboarding_slides (0004): public reads active rows, admin full CRUD.
-- Images reuse the existing `media` storage bucket under a `suggestions/` prefix
-- (same convention banners use with `banners/`) — no new bucket needed.
-- ============================================================

create table public.suggestions (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  image_url        text not null,
  content_type     text not null check (content_type in ('video', 'audio')),
  content_url      text not null,
  duration_seconds int  not null check (duration_seconds > 0),
  sort_order       int,            -- nullable: query sorts NULLs LAST (nullsFirst: false)
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Student fetch orders by (is_active, sort_order); admin list scans all rows.
create index idx_suggestions_active_order
  on public.suggestions (is_active, sort_order);

alter table public.suggestions enable row level security;

-- Anyone can read active suggestions; admin can read all (incl. inactive).
create policy "suggestions_read_active_or_admin" on public.suggestions
  for select using (is_active = true or public.is_admin());

-- Only admin can insert/update/delete.
create policy "suggestions_admin_write" on public.suggestions
  for all using (public.is_admin());

-- Keep updated_at fresh on every update.
create or replace function public.set_suggestions_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_suggestions_updated_at
  before update on public.suggestions
  for each row execute function public.set_suggestions_updated_at();

-- ============================================================
-- SOURCE: supabase/migrations/0018_suggestion_notes.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Migration 0018_suggestion_notes.sql   (Notes on suggestion videos)
-- Additive only — runs on top of schema.sql + 0001–0017.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: let a student attach a short plain-text note to a specific second of
-- a SUGGESTION video (the "مقترحات" home slider). Mirrors lesson_notes (0013)
-- but parents on suggestion_id instead of lesson_id/book_id. Strictly owner-only
-- (private notes). Deleting a suggestion cascades to its notes.
-- ============================================================

create table if not exists public.suggestion_notes (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users(id)       on delete cascade,
  suggestion_id    uuid not null references public.suggestions(id) on delete cascade,
  note_text        text not null check (char_length(btrim(note_text)) between 1 and 1000),
  position_seconds int  not null default 0 check (position_seconds >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.suggestion_notes is
  'ملحوظات الطالب النصية المرتبطة بلحظة زمنية في فيديو المقترحات.';

create index if not exists idx_suggestion_notes_user_suggestion
  on public.suggestion_notes(user_id, suggestion_id, position_seconds);

alter table public.suggestion_notes enable row level security;

-- Table privileges (RLS narrows these row-by-row).
grant select, insert, update, delete on public.suggestion_notes to authenticated;

-- RLS — strictly owner-only for every operation.
drop policy if exists "suggestion_notes_select_own" on public.suggestion_notes;
create policy "suggestion_notes_select_own" on public.suggestion_notes
  for select using (auth.uid() = user_id);

drop policy if exists "suggestion_notes_insert_own" on public.suggestion_notes;
create policy "suggestion_notes_insert_own" on public.suggestion_notes
  for insert with check (auth.uid() = user_id);

drop policy if exists "suggestion_notes_update_own" on public.suggestion_notes;
create policy "suggestion_notes_update_own" on public.suggestion_notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "suggestion_notes_delete_own" on public.suggestion_notes;
create policy "suggestion_notes_delete_own" on public.suggestion_notes
  for delete using (auth.uid() = user_id);

-- Auto-maintain updated_at (existing shared function, same as lesson_notes).
drop trigger if exists trg_suggestion_notes_updated_at on public.suggestion_notes;
create trigger trg_suggestion_notes_updated_at before update on public.suggestion_notes
  for each row execute function public.set_updated_at();

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop table if exists public.suggestion_notes;   -- removes rows, indexes, policies, trigger
*/
-- ============================================================
-- End of migration 0018_suggestion_notes.sql
-- ============================================================

-- ============================================================
-- SOURCE: supabase/migrations/0019_bank_lesson_summaries.sql
-- ============================================================
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

-- ============================================================
-- SOURCE: supabase/migrations/0020_practice_exams.sql
-- ============================================================
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

-- ============================================================
-- SOURCE: supabase/migrations/0021_final_exam_source_fk_set_null.sql
-- ============================================================
-- ============================================================
-- Sheikhy — Companion Migration 0021_final_exam_source_fk_set_null.sql
-- Additive / idempotent — safe to re-run. Run ONCE in the Supabase SQL Editor.
--
-- Fixes: deleting a lesson quiz question that was imported into a book's final
-- exam failed with
--   violates foreign key constraint
--   "final_exam_questions_source_quiz_question_id_fkey"
-- because the base-schema FK final_exam_questions.source_quiz_question_id
-- → lesson_quiz_questions(id) had the default ON DELETE NO ACTION, which blocks
-- the delete (and the same block fires on a cascading lesson delete).
--
-- source_quiz_question_id is only a provenance marker: final_exam_questions
-- keeps its OWN copy of question_text / choice_* / correct_choice, so the exam
-- question does not depend on the source row's content. Switching the FK to
-- ON DELETE SET NULL therefore lets the source question be deleted while the
-- exam question stays intact (it just loses the "imported from" link). This
-- also mirrors lesson_quiz_questions.source_question_id (migration 0019), which
-- already uses ON DELETE SET NULL.
-- ============================================================

alter table public.final_exam_questions
  drop constraint if exists final_exam_questions_source_quiz_question_id_fkey;

alter table public.final_exam_questions
  add constraint final_exam_questions_source_quiz_question_id_fkey
    foreign key (source_quiz_question_id)
    references public.lesson_quiz_questions(id)
    on delete set null;

-- ============================================================
-- SOURCE: supabase/migrations/0022_app_secrets.sql
-- ============================================================
-- supabase/migrations/0022_app_secrets.sql
-- Admin-editable server secrets (additive-only).
--
-- Purpose: let the single admin rotate the Gemini API key in-app without the
-- developer touching Supabase secrets. The raw value is NEVER exposed to the
-- client: the table has RLS enabled with NO client-facing policy, so the
-- anon/admin JWT cannot read or write it. The value is read server-side only by
-- the Edge Functions (service role bypasses RLS). The client goes exclusively
-- through the SECURITY DEFINER RPCs below, which are admin-guarded and only ever
-- return a masked status — never the full key.

-- ------------------------------------------------------------
-- 1. app_secrets table (key/value, RLS on, no client policy)
-- ------------------------------------------------------------
create table if not exists public.app_secrets (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_secrets enable row level security;
-- Intentionally no policies: client (anon/authenticated) can neither read nor
-- write. Service role bypasses RLS for the Edge Functions; admins use the RPCs.

-- ------------------------------------------------------------
-- 2. set_app_secret(p_key, p_value) — admin upsert
-- ------------------------------------------------------------
create or replace function public.set_app_secret(p_key text, p_value text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_value is null or length(trim(p_value)) = 0 then
    raise exception 'empty value' using errcode = '22023';
  end if;

  insert into public.app_secrets (key, value, updated_at)
  values (p_key, trim(p_value), now())
  on conflict (key)
  do update set value = excluded.value, updated_at = now();
end;
$$;

-- ------------------------------------------------------------
-- 3. clear_app_secret(p_key) — admin delete
-- ------------------------------------------------------------
create or replace function public.clear_app_secret(p_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.app_secrets where key = p_key;
end;
$$;

-- ------------------------------------------------------------
-- 4. get_secret_status(p_key) — admin masked status
--    Returns { is_set, last4, updated_at }; never the full value.
-- ------------------------------------------------------------
create or replace function public.get_secret_status(p_key text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_value      text;
  v_updated_at timestamptz;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select value, updated_at into v_value, v_updated_at
  from public.app_secrets where key = p_key;

  if v_value is null then
    return json_build_object('is_set', false, 'last4', null, 'updated_at', null);
  end if;

  return json_build_object(
    'is_set', true,
    'last4', right(v_value, 4),
    'updated_at', v_updated_at
  );
end;
$$;

grant execute on function public.set_app_secret(text, text) to authenticated;
grant execute on function public.clear_app_secret(text) to authenticated;
grant execute on function public.get_secret_status(text) to authenticated;

-- ============================================================
-- SOURCE: supabase/migrations/0023_revoke_public_exec.sql
-- ============================================================
-- supabase/migrations/0023_revoke_public_exec.sql
-- Harden app_secrets RPCs: revoke execute from public/anon before re-granting
-- to authenticated only.
--
-- Background: PostgreSQL grants EXECUTE to PUBLIC by default when a function
-- is created, so the anon role (unauthenticated Supabase clients) can invoke
-- these RPCs. The is_admin() guard inside each function prevents any actual
-- access to the key, but the connection is accepted and the function body runs
-- up to the guard check. Defense-in-depth: block the call at the grant level
-- so anon receives a 403 from PostgREST before the function even executes.
--
-- Idempotent: REVOKE of a non-held privilege is a no-op in PostgreSQL.
-- Safe to run on the live project — the existing authenticated grants remain
-- in effect; this only removes the implicit public/anon grant.

revoke execute on function public.set_app_secret(text, text) from public;
revoke execute on function public.set_app_secret(text, text) from anon;
grant  execute on function public.set_app_secret(text, text) to authenticated;

revoke execute on function public.clear_app_secret(text) from public;
revoke execute on function public.clear_app_secret(text) from anon;
grant  execute on function public.clear_app_secret(text) to authenticated;

revoke execute on function public.get_secret_status(text) from public;
revoke execute on function public.get_secret_status(text) from anon;
grant  execute on function public.get_secret_status(text) to authenticated;

-- ── Other SECURITY DEFINER functions in this repo with the same missing-revoke
--    pattern (grant to authenticated only, no revoke from public/anon).
--    NOT fixed here — listed for the next hardening migration.
--
--    Function                             Defined in
--    ─────────────────────────────────── ──────────────────────────────
--    reorder_lessons(jsonb)               0002_hardening.sql
--    grade_lesson_quiz(uuid, jsonb)       0005_guest_mode / 0014_quiz_entitlement
--    submit_final_exam(uuid,jsonb,tstz)   0005_guest_mode / 0006_notification_scoping
--    submit_lesson_quiz(uuid, jsonb)      0005_guest_mode / 0014_quiz_entitlement
--    get_lesson_quiz_review(uuid, int)    0005_guest_mode / 0014_quiz_entitlement
--    get_final_exam_review(uuid, uuid)    0005_guest_mode
--    get_my_study_seconds()               0015_lesson_duration
--    bank_lesson_summaries(uuid)          0019_bank_lesson_summaries
--
--    Intentionally excluded (anon access is correct by design):
--    is_guest()              — must be callable by anon (guest-mode detection)
--    can_read_lesson(uuid,uuid) — must be callable by anon (guest lesson access)
--
--    Trigger functions (enforce_featured_cap, sync_lesson_pdf_url,
--    handle_new_user, handle_anon_conversion, prune_practice_attempts) are
--    invoked by PostgreSQL triggers only, not via PostgREST RPC, so grant/
--    revoke on them has no client-facing effect.

