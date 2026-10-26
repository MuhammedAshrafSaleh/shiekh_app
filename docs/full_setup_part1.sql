-- ============================================================
-- docs/full_setup_part1.sql — Sheikhy setup, Part 1 of 4
-- ============================================================
-- Migrations 0000–0004  (baseline + initial RPCs/views)
-- Run the four parts in order (part1 → part2 → part3 → part4);
-- each part assumes every earlier part already succeeded.
-- Part 1 STARTS WITH 0000_baseline.sql — run this one first.
--
-- [!] Elevated-privilege statements (postgres role; fine in the
--     Supabase SQL Editor):
--       • CREATE TRIGGER on_auth_user_created ON auth.users
-- Generated: 2026-10-26
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
-- EXPLICIT SCHEMA GRANTS
-- Required when "Automatically expose new tables" is OFF at project
-- creation, or after DROP SCHEMA public CASCADE resets privileges.
-- RLS is the real access-control layer; these grants only allow
-- roles to reach the schema.  Without them PostgREST returns
-- "42501: permission denied for schema public" on every table.
--
-- The four GRANT … ON ALL … lines cover objects that already exist
-- at this point in the file.  The three ALTER DEFAULT PRIVILEGES
-- lines cover every table/sequence/routine created by migrations
-- 0001–0024 and beyond.
--
-- 0023_revoke_public_exec.sql runs after this and overrides the
-- routine grant for the app_secrets RPCs — correct behaviour.
-- ============================================================

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables     in schema public to anon, authenticated, service_role;
grant all on all sequences  in schema public to anon, authenticated, service_role;
grant all on all routines   in schema public to anon, authenticated, service_role;

alter default privileges in schema public
  grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on routines  to anon, authenticated, service_role;

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

