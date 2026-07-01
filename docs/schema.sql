-- ============================================================
-- شيخي (Sheikhy) - Database Schema for Supabase (PostgreSQL)
-- الإصدار: 1.0
-- ============================================================
-- ترتيب التنفيذ: هذا الملف مرتب بحيث يمكن تشغيله كاملاً دفعة واحدة
-- في Supabase SQL Editor دون أخطاء Foreign Key.
-- ============================================================

-- ------------------------------------------------------------
-- 0. الإعدادات الأساسية
-- ------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- Enum بسيط لدور المستخدم
create type user_role as enum ('student', 'admin');

-- Enum لحالة النشر (منشور/مسودة)
create type publish_status as enum ('draft', 'published');

-- Enum لمؤشر تقدم تجهيز المحتوى (مؤشر داخلي للأدمن فقط)
create type review_status as enum ('in_review', 'completed');

-- Enum لحالة سؤال الطالب (بانتظار الرد / تم الرد)
create type question_status as enum ('pending', 'answered');

-- Enum لنوع الإشعار
create type notification_type as enum ('general', 'live_stream', 'new_lesson', 'reminder', 'achievement');

-- ------------------------------------------------------------
-- 1. USERS — جدول المستخدمين (طالب + أدمن في جدول واحد)
-- ------------------------------------------------------------
-- ملاحظة: هذا الجدول يمتد جدول auth.users الخاص بـ Supabase Auth
-- عبر مفتاح أساسي مطابق لـ auth.users.id

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'student',
  full_name text not null,
  email text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.users is 'بيانات المستخدمين الإضافية (طالب أو أدمن) المرتبطة بحساب Supabase Auth';
comment on column public.users.role is 'يحدد التوجيه بعد تسجيل الدخول: student أو admin';

-- ------------------------------------------------------------
-- 2. SECTIONS — الأقسام العلمية
-- ------------------------------------------------------------
create table public.sections (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  icon text not null,                -- اسم الأيقونة من المجموعة الثابتة (8 أيقونات)
  description text,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.sections is 'الأقسام العلمية مثل العقيدة، الفقه، التفسير';

-- ------------------------------------------------------------
-- 3. BOOKS — الكتب
-- ------------------------------------------------------------
create table public.books (
  id uuid primary key default uuid_generate_v4(),
  section_id uuid not null references public.sections(id) on delete restrict,
  title text not null,
  description text,
  cover_image_url text,
  status publish_status not null default 'draft',       -- منشور / مسودة (يتحكم في ظهوره للطلاب)
  review_status review_status not null default 'in_review', -- مكتمل / قيد المراجعة (مؤشر داخلي للأدمن فقط)
  is_featured boolean not null default false,            -- يظهر في "أهم الكتب" بالرئيسية
  featured_order int,                                     -- ترتيب يدوي للكتب المميزة
  created_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.books is 'الكتب العلمية، كل كتاب ينتمي لقسم علمي واحد';
comment on column public.books.status is 'منشور أو مسودة - يتحكم في ظهور الكتاب للطلاب';
comment on column public.books.review_status is 'مكتمل أو قيد المراجعة - مؤشر داخلي للأدمن فقط، لا يؤثر على ظهور الكتاب';
comment on column public.books.is_featured is 'يحدد ظهور الكتاب في قائمة أهم الكتب بالصفحة الرئيسية';

create index idx_books_section on public.books(section_id);
create index idx_books_featured on public.books(is_featured, featured_order) where is_featured = true;

-- ------------------------------------------------------------
-- 4. LESSONS — الدروس
-- ------------------------------------------------------------
create table public.lessons (
  id uuid primary key default uuid_generate_v4(),
  book_id uuid not null references public.books(id) on delete cascade,
  order_index int not null,             -- ترتيب الدرس داخل الكتاب
  title text not null,
  description text,
  video_url text,                       -- لينك يوتيوب (Unlisted)
  audio_url text,                       -- لينك Google Drive (يُحوَّل لصيغة تحميل مباشر)
  pdf_url text,                         -- لينك Google Drive
  audio_only boolean not null default false,  -- "هذا الدرس صوت فقط بدون فيديو"
  status publish_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (book_id, order_index)
);

comment on table public.lessons is 'الدروس داخل كل كتاب؛ كل درس يحتوي فيديو/صوت/PDF/اختبار قصير (اختياري كل عنصر)';
comment on column public.lessons.audio_url is 'لينك Google Drive للملف الصوتي - يُحوَّل في التطبيق لصيغة تحميل مباشر (uc?export=download)';

create index idx_lessons_book on public.lessons(book_id, order_index);

-- ------------------------------------------------------------
-- 5. LESSON_QUIZ_QUESTIONS — أسئلة اختبار الدرس القصير
-- ------------------------------------------------------------
create table public.lesson_quiz_questions (
  id uuid primary key default uuid_generate_v4(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  order_index int not null default 0,
  question_text text not null,
  choice_a text not null,
  choice_b text not null,
  choice_c text not null,
  choice_d text not null,
  correct_choice char(1) not null check (correct_choice in ('a','b','c','d')),
  created_at timestamptz not null default now()
);

comment on table public.lesson_quiz_questions is 'أسئلة الاختبار القصير الخاص بكل درس - تُستخدم أيضًا كبنك أسئلة اختياري لبناء الاختبار الشامل';

create index idx_quiz_lesson on public.lesson_quiz_questions(lesson_id);

-- ------------------------------------------------------------
-- 6. FINAL_EXAM_SETTINGS — إعدادات الاختبار الشامل لكل كتاب
-- ------------------------------------------------------------
create table public.final_exam_settings (
  book_id uuid primary key references public.books(id) on delete cascade,
  time_limit_minutes int not null default 30,
  passing_percentage int not null default 70,
  max_attempts int not null default 2,
  is_published boolean not null default false,
  updated_at timestamptz not null default now()
);

comment on table public.final_exam_settings is 'إعدادات قابلة للتخصيص لكل كتاب: الوقت المتاح، نسبة النجاح، عدد المحاولات المسموحة';

-- ------------------------------------------------------------
-- 7. FINAL_EXAM_QUESTIONS — أسئلة الاختبار الشامل
-- ------------------------------------------------------------
create table public.final_exam_questions (
  id uuid primary key default uuid_generate_v4(),
  book_id uuid not null references public.books(id) on delete cascade,
  order_index int not null default 0,
  question_text text not null,
  choice_a text not null,
  choice_b text not null,
  choice_c text not null,
  choice_d text not null,
  correct_choice char(1) not null check (correct_choice in ('a','b','c','d')),
  source_quiz_question_id uuid references public.lesson_quiz_questions(id), -- لو السؤال مُستورد من بنك الأسئلة
  created_at timestamptz not null default now()
);

comment on table public.final_exam_questions is 'أسئلة الاختبار الشامل لكل كتاب، يدخلها الشيخ يدويًا أو يستوردها من بنك أسئلة الدروس';
comment on column public.final_exam_questions.source_quiz_question_id is 'مرجع اختياري للسؤال الأصلي في بنك الأسئلة لو تم الاستيراد منه';

create index idx_final_exam_q_book on public.final_exam_questions(book_id, order_index);

-- ------------------------------------------------------------
-- 8. ENROLLMENTS — تسجيل الطالب في كتاب
-- ------------------------------------------------------------
create table public.enrollments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  unique (user_id, book_id)
);

comment on table public.enrollments is 'سجل تسجيل الطالب الفعلي في كتاب، يُنشأ بعد تأكيد زر "تسجيل في الكتاب" (Confirmation Dialog)';

create index idx_enrollments_user on public.enrollments(user_id);
create index idx_enrollments_book on public.enrollments(book_id);

-- ------------------------------------------------------------
-- 9. LESSON_PROGRESS — تقدم الطالب في كل درس
-- ------------------------------------------------------------
create table public.lesson_progress (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  completed boolean not null default false,
  last_position_seconds int default 0,   -- لاستئناف الفيديو من حيث توقف
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, lesson_id)
);

comment on table public.lesson_progress is 'تتبع تقدم كل طالب في كل درس على حدة، يُستخدم لحساب نسبة إكمال الكتاب';

create index idx_progress_user on public.lesson_progress(user_id);
create index idx_progress_lesson on public.lesson_progress(lesson_id);

-- ------------------------------------------------------------
-- 10. FINAL_EXAM_ATTEMPTS — محاولات الاختبار الشامل
-- ------------------------------------------------------------
create table public.final_exam_attempts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  attempt_number int not null,
  score_percentage int not null,
  passed boolean not null,
  answers jsonb not null default '{}',   -- { question_id: chosen_choice }
  started_at timestamptz not null default now(),
  submitted_at timestamptz
);

comment on table public.final_exam_attempts is 'سجل كل محاولة اختبار شامل لكل طالب، بما فيها الإجابات التفصيلية';

create index idx_attempts_user_book on public.final_exam_attempts(user_id, book_id);

-- ------------------------------------------------------------
-- 11. CERTIFICATES — الشهادات
-- ------------------------------------------------------------
create table public.certificates (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  final_exam_attempt_id uuid references public.final_exam_attempts(id),
  final_score int not null,
  grade_label text,                       -- مثل "ممتاز"
  issued_at timestamptz not null default now(),
  pdf_url text,                           -- لينك الشهادة المولّدة
  unique (user_id, book_id)
);

comment on table public.certificates is 'الشهادات الممنوحة للطالب بعد نجاحه في الاختبار الشامل لكتاب معيّن';

create index idx_certificates_user on public.certificates(user_id);

-- ------------------------------------------------------------
-- 12. STUDENT_QUESTIONS — أسئلة وأجوبة الطلاب (Q&A)
-- ------------------------------------------------------------
create table public.student_questions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  question_text text not null,
  answer_text text,
  status question_status not null default 'pending',
  answered_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.student_questions is 'أسئلة الطلاب: تُدخل في سياق درس معيّن، وتُعرض في شاشة موحّدة على مستوى الكتاب. هوية السائل تظهر للأدمن دومًا وتكون مجهولة أمام باقي الطلاب';

create index idx_questions_book on public.student_questions(book_id);
create index idx_questions_lesson on public.student_questions(lesson_id);
create index idx_questions_status on public.student_questions(status);

-- ------------------------------------------------------------
-- 13. NOTIFICATIONS — الإشعارات
-- ------------------------------------------------------------
create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  type notification_type not null default 'general',
  title text not null,
  body text not null,
  link_url text,                          -- لينك بث مباشر أو لينك كتاب/درس
  send_at timestamptz not null default now(),  -- يدعم الإرسال الفوري أو المجدول
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.notifications is 'الإشعارات المُرسلة لكل الطلاب، تُدار من لوحة تحكم الأدمن';

-- ------------------------------------------------------------
-- 14. NOTIFICATION_READS — حالة قراءة كل إشعار لكل طالب
-- ------------------------------------------------------------
create table public.notification_reads (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  read_at timestamptz not null default now(),
  unique (user_id, notification_id)
);

comment on table public.notification_reads is 'يسجل قراءة كل طالب لكل إشعار، يُستخدم لعرض حالة (مقروء/غير مقروء) ولزر "تحديد الكل كمقروء"';

-- ------------------------------------------------------------
-- 15. HOME_BANNERS — بانرات الصفحة الرئيسية
-- ------------------------------------------------------------
create table public.home_banners (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  image_url text,
  linked_book_id uuid references public.books(id),  -- لينك لكتاب معيّن (اختياري)
  external_link text,                                -- لينك خارجي (اختياري، مثل بث مباشر)
  order_index int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.home_banners is 'بانرات Carousel الصفحة الرئيسية، تُدار بالكامل من شاشة "إدارة البانر" في الأدمن';

create index idx_banners_active on public.home_banners(is_active, order_index);

-- ============================================================
-- نهاية تعريفات الجداول
-- ============================================================


-- ============================================================
-- 16. دوال ومحفزات مساعدة (Helper Functions & Triggers)
-- ============================================================

-- تحديث updated_at تلقائيًا عند أي تعديل
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();

create trigger trg_books_updated_at before update on public.books
  for each row execute function public.set_updated_at();

create trigger trg_lessons_updated_at before update on public.lessons
  for each row execute function public.set_updated_at();

create trigger trg_progress_updated_at before update on public.lesson_progress
  for each row execute function public.set_updated_at();

-- دالة مساعدة: التحقق إن المستخدم الحالي أدمن (تُستخدم داخل RLS Policies)
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;

-- ============================================================
-- 17. تفعيل Row Level Security (RLS) على كل الجداول
-- ============================================================

alter table public.users enable row level security;
alter table public.sections enable row level security;
alter table public.books enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_quiz_questions enable row level security;
alter table public.final_exam_settings enable row level security;
alter table public.final_exam_questions enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.final_exam_attempts enable row level security;
alter table public.certificates enable row level security;
alter table public.student_questions enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_reads enable row level security;
alter table public.home_banners enable row level security;

-- ------------------------------------------------------------
-- Policies: USERS
-- ------------------------------------------------------------
create policy "users_select_own_or_admin" on public.users
  for select using (auth.uid() = id or public.is_admin());

create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);

-- ------------------------------------------------------------
-- Policies: SECTIONS (قراءة عامة، كتابة للأدمن فقط)
-- ------------------------------------------------------------
create policy "sections_select_all" on public.sections
  for select using (true);

create policy "sections_admin_write" on public.sections
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: BOOKS (الطلاب يشوفوا المنشور فقط، الأدمن يشوف ويكتب الكل)
-- ------------------------------------------------------------
create policy "books_select_published_or_admin" on public.books
  for select using (status = 'published' or public.is_admin());

create policy "books_admin_write" on public.books
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: LESSONS
-- ------------------------------------------------------------
create policy "lessons_select_published_or_admin" on public.lessons
  for select using (status = 'published' or public.is_admin());

create policy "lessons_admin_write" on public.lessons
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: LESSON_QUIZ_QUESTIONS
-- ------------------------------------------------------------
create policy "quiz_select_all" on public.lesson_quiz_questions
  for select using (true);

create policy "quiz_admin_write" on public.lesson_quiz_questions
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: FINAL_EXAM_SETTINGS
-- ------------------------------------------------------------
create policy "exam_settings_select_all" on public.final_exam_settings
  for select using (true);

create policy "exam_settings_admin_write" on public.final_exam_settings
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: FINAL_EXAM_QUESTIONS
-- (الطالب يشوف الأسئلة بس بدون عمود correct_choice عبر View منفصل لاحقًا عند التنفيذ)
-- ------------------------------------------------------------
create policy "final_exam_q_select_all" on public.final_exam_questions
  for select using (true);

create policy "final_exam_q_admin_write" on public.final_exam_questions
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: ENROLLMENTS
-- ------------------------------------------------------------
create policy "enrollments_select_own_or_admin" on public.enrollments
  for select using (auth.uid() = user_id or public.is_admin());

create policy "enrollments_insert_own" on public.enrollments
  for insert with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Policies: LESSON_PROGRESS
-- ------------------------------------------------------------
create policy "progress_select_own_or_admin" on public.lesson_progress
  for select using (auth.uid() = user_id or public.is_admin());

create policy "progress_upsert_own" on public.lesson_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Policies: FINAL_EXAM_ATTEMPTS
-- ------------------------------------------------------------
create policy "attempts_select_own_or_admin" on public.final_exam_attempts
  for select using (auth.uid() = user_id or public.is_admin());

create policy "attempts_insert_own" on public.final_exam_attempts
  for insert with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Policies: CERTIFICATES
-- ------------------------------------------------------------
create policy "certificates_select_own_or_admin" on public.certificates
  for select using (auth.uid() = user_id or public.is_admin());

-- ------------------------------------------------------------
-- Policies: STUDENT_QUESTIONS
-- الطالب يشوف كل الأسئلة (هوية السائل تُخفى في طبقة العرض/View لاحقًا)
-- الطالب يضيف سؤاله بس، الأدمن يرد (Update)
-- ------------------------------------------------------------
create policy "questions_select_all" on public.student_questions
  for select using (true);

create policy "questions_insert_own" on public.student_questions
  for insert with check (auth.uid() = user_id);

create policy "questions_admin_update" on public.student_questions
  for update using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: NOTIFICATIONS
-- ------------------------------------------------------------
create policy "notifications_select_all" on public.notifications
  for select using (true);

create policy "notifications_admin_write" on public.notifications
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- Policies: NOTIFICATION_READS
-- ------------------------------------------------------------
create policy "notif_reads_select_own" on public.notification_reads
  for select using (auth.uid() = user_id);

create policy "notif_reads_insert_own" on public.notification_reads
  for insert with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Policies: HOME_BANNERS
-- ------------------------------------------------------------
create policy "banners_select_active_or_admin" on public.home_banners
  for select using (is_active = true or public.is_admin());

create policy "banners_admin_write" on public.home_banners
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- نهاية الملف
-- ============================================================
