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
