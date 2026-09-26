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