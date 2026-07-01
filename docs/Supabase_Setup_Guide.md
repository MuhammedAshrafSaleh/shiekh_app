# 🚀 Supabase Setup Guide — تطبيق شيخي (Sheikhy)
**خطوة بخطوة من الصفر — للمبتدئين والمحترفين**

---

## الخطوة 1 — إنشاء الحساب والمشروع

### 1.1 إنشاء حساب
1. اذهب إلى **https://supabase.com**
2. اضغط **"Start your project"**
3. سجّل بـ GitHub account (الأسهل والأسرع)

### 1.2 إنشاء مشروع جديد
1. بعد تسجيل الدخول اضغط **"New Project"**
2. اختر **Organization** (هيتعمل تلقائيًا باسمك)
3. املأ البيانات:

```
Project Name:  sheikhy-[اسم الشيخ]   (مثال: sheikhy-fawzan)
Database Password: [اختر باسورد قوي واحتفظ بيه في مكان آمن]
Region: eu-central-1 (Frankfurt)
Plan: Free
```

4. اضغط **"Create new project"**
5. انتظر 2-3 دقائق حتى يكتمل الإنشاء ⏳

> ⚠️ **مهم:** كل شيخ جديد = مشروع Supabase جديد مستقل تمامًا. نفس الخطوات دي هتتكرر لكل شيخ.

---

## الخطوة 2 — فهم الـ Dashboard

```
Supabase Dashboard
├── Table Editor      → بتشوف وتعدل البيانات مباشرة (زي Excel)
├── SQL Editor        → بتكتب SQL مباشرة (ده اللي هنستخدمه أكتر)
├── Database
│   ├── Tables        → إدارة الجداول
│   ├── Functions     → الـ PostgreSQL functions
│   ├── Triggers      → الـ DB triggers
│   └── Types         → الـ Enums اللي هنعملها
├── Auth              → إعدادات المستخدمين والـ email
├── Storage           → الـ buckets للصور
├── Edge Functions    → Serverless functions
└── Settings
    └── API           → بتلاقي هنا الـ keys بتاعتك
```

---

## الخطوة 3 — إعداد الـ Authentication

### 3.1 تفعيل Email Auth فقط
1. اذهب إلى **Authentication → Providers**
2. تأكد إن **Email** مفعّل ✅
3. تأكد إن **Google** وأي Provider تاني **Disabled** ❌
4. في إعدادات Email:
   - **"Confirm email"** → OFF في مرحلة التطوير
   - **"Secure email change"** → ON ✅

### 3.2 إعداد Email Templates
1. اذهب إلى **Authentication → Email Templates**
2. اختر **"Reset Password"**
3. عدّل الـ Subject:
```
إعادة تعيين كلمة المرور — شيخي
```
4. اضغط **Save**

### 3.3 إعداد الـ Redirect URLs
1. اذهب إلى **Authentication → URL Configuration**
2. في **"Site URL"** حط:
```
io.sheikhy.app://reset-callback
```
3. في **"Redirect URLs"** أضف:
```
io.sheikhy.app://reset-callback
io.sheikhy.app://**
```

---

## الخطوة 4 — إنشاء الـ Database

### ⚠️ قواعد مهمة قبل البدء

```
✅ كل SQL block = New Query منفصل في الـ SQL Editor
✅ بعد كل Run تأكد من رسالة: "Success. No rows returned"
✅ لو ظهر أي خطأ، ابعته وما تكملش للخطوة الجاية
✅ الترتيب إلزامي بسبب الـ Foreign Keys
```

---

### 4.1 Extensions + Enums

```sql
create extension if not exists "uuid-ossp";

create type user_role as enum ('student', 'admin');
create type publish_status as enum ('draft', 'published');
create type review_status as enum ('in_review', 'completed');
create type question_status as enum ('pending', 'answered');
create type notification_type as enum (
  'general', 'live_stream', 'new_lesson', 'reminder', 'achievement'
);
```

✅ Run — **للتأكد:** Database → Types — لازم تشوف 5 enums

---

### 4.2 جدول users

```sql
create table public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       user_role not null default 'student',
  full_name  text not null,
  email      text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.users is 'بيانات المستخدمين - طالب أو أدمن في جدول واحد';
comment on column public.users.role is 'يحدد التوجيه بعد تسجيل الدخول: student أو admin';
```

✅ Run

---

### 4.3 جدول sections

```sql
create table public.sections (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  icon        text not null,
  description text,
  created_by  uuid references public.users(id),
  created_at  timestamptz not null default now()
);

comment on table public.sections is 'الأقسام العلمية مثل العقيدة والفقه والتفسير';
```

✅ Run

---

### 4.4 جدول books

```sql
create table public.books (
  id              uuid primary key default uuid_generate_v4(),
  section_id      uuid not null references public.sections(id) on delete restrict,
  title           text not null,
  description     text,
  cover_image_url text,
  status          publish_status not null default 'draft',
  review_status   review_status not null default 'in_review',
  is_featured     boolean not null default false,
  featured_order  int,
  created_by      uuid references public.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on column public.books.status is 'منشور أو مسودة - يتحكم في ظهور الكتاب للطلاب';
comment on column public.books.review_status is 'مكتمل أو قيد المراجعة - مؤشر داخلي للأدمن فقط';
comment on column public.books.is_featured is 'يظهر في قائمة أهم الكتب بالصفحة الرئيسية';

create index idx_books_section  on public.books(section_id);
create index idx_books_featured on public.books(is_featured, featured_order)
  where is_featured = true;
```

✅ Run

---

### 4.5 جدول lessons

```sql
create table public.lessons (
  id          uuid primary key default uuid_generate_v4(),
  book_id     uuid not null references public.books(id) on delete cascade,
  order_index int not null,
  title       text not null,
  description text,
  video_url   text,
  audio_url   text,
  pdf_url     text,
  audio_only  boolean not null default false,
  status      publish_status not null default 'draft',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (book_id, order_index)
);

comment on column public.lessons.video_url  is 'لينك يوتيوب Unlisted';
comment on column public.lessons.audio_url  is 'لينك Google Drive - يُحوَّل لصيغة تحميل مباشر في التطبيق';
comment on column public.lessons.pdf_url    is 'لينك Google Drive';
comment on column public.lessons.audio_only is 'هذا الدرس صوت فقط بدون فيديو';

create index idx_lessons_book on public.lessons(book_id, order_index);
```

✅ Run

---

### 4.6 جدول lesson_quiz_questions

```sql
create table public.lesson_quiz_questions (
  id             uuid primary key default uuid_generate_v4(),
  lesson_id      uuid not null references public.lessons(id) on delete cascade,
  order_index    int not null default 0,
  question_text  text not null,
  choice_a       text not null,
  choice_b       text not null,
  choice_c       text not null,
  choice_d       text not null,
  correct_choice char(1) not null check (correct_choice in ('a','b','c','d')),
  created_at     timestamptz not null default now()
);

comment on table public.lesson_quiz_questions is
  'أسئلة اختبار الدرس القصير - تُستخدم أيضًا كبنك أسئلة للاختبار الشامل';

create index idx_quiz_lesson on public.lesson_quiz_questions(lesson_id);
```

✅ Run

---

### 4.7 جدول final_exam_settings

```sql
create table public.final_exam_settings (
  book_id            uuid primary key references public.books(id) on delete cascade,
  time_limit_minutes int not null default 30,
  passing_percentage int not null default 70,
  max_attempts       int not null default 2,
  is_published       boolean not null default false,
  updated_at         timestamptz not null default now()
);

comment on table public.final_exam_settings is
  'إعدادات الاختبار الشامل لكل كتاب: الوقت، نسبة النجاح، عدد المحاولات';
```

✅ Run

---

### 4.8 جدول final_exam_questions

```sql
create table public.final_exam_questions (
  id                      uuid primary key default uuid_generate_v4(),
  book_id                 uuid not null references public.books(id) on delete cascade,
  order_index             int not null default 0,
  question_text           text not null,
  choice_a                text not null,
  choice_b                text not null,
  choice_c                text not null,
  choice_d                text not null,
  correct_choice          char(1) not null check (correct_choice in ('a','b','c','d')),
  source_quiz_question_id uuid references public.lesson_quiz_questions(id),
  created_at              timestamptz not null default now()
);

comment on column public.final_exam_questions.source_quiz_question_id is
  'مرجع اختياري للسؤال الأصلي في بنك الأسئلة لو تم الاستيراد منه';

create index idx_final_exam_q_book on public.final_exam_questions(book_id, order_index);
```

✅ Run

---

### 4.9 جدول enrollments

```sql
create table public.enrollments (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  book_id     uuid not null references public.books(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  unique (user_id, book_id)
);

comment on table public.enrollments is
  'تسجيل الطالب في كتاب - يُنشأ بعد تأكيد Confirmation Dialog';

create index idx_enrollments_user on public.enrollments(user_id);
create index idx_enrollments_book on public.enrollments(book_id);
```

✅ Run

---

### 4.10 جدول lesson_progress

```sql
create table public.lesson_progress (
  id                    uuid primary key default uuid_generate_v4(),
  user_id               uuid not null references public.users(id) on delete cascade,
  lesson_id             uuid not null references public.lessons(id) on delete cascade,
  completed             boolean not null default false,
  last_position_seconds int default 0,
  completed_at          timestamptz,
  updated_at            timestamptz not null default now(),
  unique (user_id, lesson_id)
);

comment on column public.lesson_progress.last_position_seconds is
  'لاستئناف الفيديو من حيث توقف الطالب';

create index idx_progress_user   on public.lesson_progress(user_id);
create index idx_progress_lesson on public.lesson_progress(lesson_id);
```

✅ Run

---

### 4.11 جدول final_exam_attempts

```sql
create table public.final_exam_attempts (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  book_id          uuid not null references public.books(id) on delete cascade,
  attempt_number   int not null,
  score_percentage int not null,
  passed           boolean not null,
  answers          jsonb not null default '{}',
  started_at       timestamptz not null default now(),
  submitted_at     timestamptz
);

comment on column public.final_exam_attempts.answers is
  'JSON: { "question_id": "chosen_choice" }';

create index idx_attempts_user_book on public.final_exam_attempts(user_id, book_id);
```

✅ Run

---

### 4.12 جدول certificates

```sql
create table public.certificates (
  id                    uuid primary key default uuid_generate_v4(),
  user_id               uuid not null references public.users(id) on delete cascade,
  book_id               uuid not null references public.books(id) on delete cascade,
  final_exam_attempt_id uuid references public.final_exam_attempts(id),
  final_score           int not null,
  grade_label           text,
  issued_at             timestamptz not null default now(),
  pdf_url               text,
  unique (user_id, book_id)
);

comment on column public.certificates.grade_label is 'مثل: ممتاز، جيد جداً، جيد';

create index idx_certificates_user on public.certificates(user_id);
```

✅ Run

---

### 4.13 جدول student_questions

```sql
create table public.student_questions (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  book_id       uuid not null references public.books(id) on delete cascade,
  lesson_id     uuid not null references public.lessons(id) on delete cascade,
  question_text text not null,
  answer_text   text,
  status        question_status not null default 'pending',
  answered_at   timestamptz,
  created_at    timestamptz not null default now()
);

comment on table public.student_questions is
  'أسئلة الطلاب: تُدخل في سياق درس، تُعرض موحّدة على مستوى الكتاب';

create index idx_questions_book   on public.student_questions(book_id);
create index idx_questions_lesson on public.student_questions(lesson_id);
create index idx_questions_status on public.student_questions(status);
```

✅ Run

---

### 4.14 جدول notifications

```sql
create table public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  type       notification_type not null default 'general',
  title      text not null,
  body       text not null,
  link_url   text,
  send_at    timestamptz not null default now(),
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on column public.notifications.link_url is
  'لينك بث مباشر أو لينك كتاب/درس معيّن';
comment on column public.notifications.send_at is
  'يدعم الإرسال الفوري أو المجدول';
```

✅ Run

---

### 4.15 جدول notification_reads

```sql
create table public.notification_reads (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.users(id) on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  read_at         timestamptz not null default now(),
  unique (user_id, notification_id)
);

comment on table public.notification_reads is
  'قراءة الإشعارات - يُستخدم لزر "تحديد الكل كمقروء"';
```

✅ Run

---

### 4.16 جدول home_banners

```sql
create table public.home_banners (
  id             uuid primary key default uuid_generate_v4(),
  title          text not null,
  description    text,
  image_url      text,
  linked_book_id uuid references public.books(id),
  external_link  text,
  order_index    int not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

comment on column public.home_banners.linked_book_id is 'لينك لكتاب معيّن (اختياري)';
comment on column public.home_banners.external_link  is 'لينك خارجي مثل بث مباشر (اختياري)';

create index idx_banners_active on public.home_banners(is_active, order_index);
```

✅ Run

**للتأكد من كل الجداول:** اذهب إلى **Table Editor** — لازم تشوف 16 جدول

---

## الخطوة 5 — الـ Functions والـ Triggers

### 5.1 دالة set_updated_at

```sql
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;
```

✅ Run

---

### 5.2 ربط الـ Trigger بالجداول

```sql
create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

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
```

✅ Run

---

### 5.3 دالة is_admin (مطلوبة للـ RLS)

```sql
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;
```

✅ Run

> 🔴 هذه الدالة لازم تتعمل **قبل** الـ RLS Policies

---

### 5.4 Trigger مزامنة auth.users مع public.users

```sql
create or replace function public.handle_new_user()
returns trigger as $$
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
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

✅ Run

> ✅ أي طالب بيسجل من التطبيق، هيتعمله سجل تلقائيًا في public.users بدور student

---

## الخطوة 6 — تفعيل RLS

### 6.1 تفعيل RLS على كل الجداول

```sql
alter table public.users                 enable row level security;
alter table public.sections              enable row level security;
alter table public.books                 enable row level security;
alter table public.lessons               enable row level security;
alter table public.lesson_quiz_questions enable row level security;
alter table public.final_exam_settings   enable row level security;
alter table public.final_exam_questions  enable row level security;
alter table public.enrollments           enable row level security;
alter table public.lesson_progress       enable row level security;
alter table public.final_exam_attempts   enable row level security;
alter table public.certificates          enable row level security;
alter table public.student_questions     enable row level security;
alter table public.notifications         enable row level security;
alter table public.notification_reads    enable row level security;
alter table public.home_banners          enable row level security;
```

✅ Run

---

### 6.2 Policies — users

```sql
create policy "users_select_own_or_admin" on public.users
  for select using (auth.uid() = id or public.is_admin());

create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);
```

✅ Run

---

### 6.3 Policies — sections و books

```sql
create policy "sections_select_all" on public.sections
  for select using (true);

create policy "sections_admin_write" on public.sections
  for all using (public.is_admin()) with check (public.is_admin());

create policy "books_select_published_or_admin" on public.books
  for select using (status = 'published' or public.is_admin());

create policy "books_admin_write" on public.books
  for all using (public.is_admin()) with check (public.is_admin());
```

✅ Run

---

### 6.4 Policies — lessons و lesson_quiz_questions

```sql
create policy "lessons_select_published_or_admin" on public.lessons
  for select using (status = 'published' or public.is_admin());

create policy "lessons_admin_write" on public.lessons
  for all using (public.is_admin()) with check (public.is_admin());

create policy "quiz_select_all" on public.lesson_quiz_questions
  for select using (true);

create policy "quiz_admin_write" on public.lesson_quiz_questions
  for all using (public.is_admin()) with check (public.is_admin());
```

✅ Run

---

### 6.5 Policies — final exam tables

```sql
create policy "exam_settings_select_all" on public.final_exam_settings
  for select using (true);

create policy "exam_settings_admin_write" on public.final_exam_settings
  for all using (public.is_admin()) with check (public.is_admin());

create policy "final_exam_q_select_all" on public.final_exam_questions
  for select using (true);

create policy "final_exam_q_admin_write" on public.final_exam_questions
  for all using (public.is_admin()) with check (public.is_admin());
```

✅ Run

---

### 6.6 Policies — enrollments و lesson_progress

```sql
create policy "enrollments_select_own_or_admin" on public.enrollments
  for select using (auth.uid() = user_id or public.is_admin());

create policy "enrollments_insert_own" on public.enrollments
  for insert with check (auth.uid() = user_id);

create policy "progress_select_own_or_admin" on public.lesson_progress
  for select using (auth.uid() = user_id or public.is_admin());

create policy "progress_upsert_own" on public.lesson_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

✅ Run

---

### 6.7 Policies — attempts و certificates

```sql
create policy "attempts_select_own_or_admin" on public.final_exam_attempts
  for select using (auth.uid() = user_id or public.is_admin());

create policy "attempts_insert_own" on public.final_exam_attempts
  for insert with check (auth.uid() = user_id);

create policy "certificates_select_own_or_admin" on public.certificates
  for select using (auth.uid() = user_id or public.is_admin());
```

✅ Run

---

### 6.8 Policies — student_questions

```sql
create policy "questions_select_all" on public.student_questions
  for select using (true);

create policy "questions_insert_own" on public.student_questions
  for insert with check (auth.uid() = user_id);

create policy "questions_admin_update" on public.student_questions
  for update using (public.is_admin()) with check (public.is_admin());
```

✅ Run

---

### 6.9 Policies — notifications و notification_reads و home_banners

```sql
create policy "notifications_select_all" on public.notifications
  for select using (true);

create policy "notifications_admin_write" on public.notifications
  for all using (public.is_admin()) with check (public.is_admin());

create policy "notif_reads_select_own" on public.notification_reads
  for select using (auth.uid() = user_id);

create policy "notif_reads_insert_own" on public.notification_reads
  for insert with check (auth.uid() = user_id);

create policy "banners_select_active_or_admin" on public.home_banners
  for select using (is_active = true or public.is_admin());

create policy "banners_admin_write" on public.home_banners
  for all using (public.is_admin()) with check (public.is_admin());
```

✅ Run

---

## الخطوة 7 — إنشاء أول حساب أدمن (الشيخ)

### 7.1 إنشاء الحساب
1. اذهب إلى **Authentication → Users**
2. اضغط **"Add user" → "Create new user"**
3. أدخل إيميل وباسورد الشيخ
4. اضغط **Create User**

### 7.2 ترقية الحساب لـ admin

```sql
update public.users
set role = 'admin'
where email = 'sheikh@example.com';
```

✅ Run — المتوقع: "1 row affected"

**للتأكد:**
```sql
select id, full_name, email, role from public.users;
```

---

## الخطوة 8 — الحصول على الـ API Keys

1. اذهب إلى **Settings → API**
2. احتفظ بالقيمتين دول:

```
Project URL:  https://xxxxxxxxxxxx.supabase.co
anon public:  eyJhbGciOiJIUzI1NiIsInR5cCI6...
```

> ⚠️ لا تستخدم `service_role key` في Flutter أبدًا

---

## الخطوة 9 — ربط Flutter بـ Supabase

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
```

```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xxxxxxxxxxxx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

**اختبار الاتصال:**
```dart
final result = await supabase.from('books').select().limit(1);
print(result); // لو طبع [] يبقى اشتغل ✅
```

---

## الخطوة 10 — الـ Checklist النهائي ✅

```
□ تم إنشاء المشروع في Supabase
□ تم ضبط Auth (Email only، Redirect URLs)
□ الخطوة 4.1  — Extensions + Enums (5 enums)
□ الخطوة 4.2  — جدول users
□ الخطوة 4.3  — جدول sections
□ الخطوة 4.4  — جدول books
□ الخطوة 4.5  — جدول lessons
□ الخطوة 4.6  — جدول lesson_quiz_questions
□ الخطوة 4.7  — جدول final_exam_settings
□ الخطوة 4.8  — جدول final_exam_questions
□ الخطوة 4.9  — جدول enrollments
□ الخطوة 4.10 — جدول lesson_progress
□ الخطوة 4.11 — جدول final_exam_attempts
□ الخطوة 4.12 — جدول certificates
□ الخطوة 4.13 — جدول student_questions
□ الخطوة 4.14 — جدول notifications
□ الخطوة 4.15 — جدول notification_reads
□ الخطوة 4.16 — جدول home_banners
□ الخطوة 5.1  — دالة set_updated_at
□ الخطوة 5.2  — Triggers للـ updated_at
□ الخطوة 5.3  — دالة is_admin
□ الخطوة 5.4  — Trigger مزامنة auth → public.users
□ الخطوة 6.1  — تفعيل RLS على 16 جدول
□ الخطوات 6.2→6.9 — كل الـ RLS Policies
□ الخطوة 7    — حساب الشيخ وترقيته لـ admin
□ الخطوة 8    — نسخ Project URL و anon key
□ الخطوة 9    — اختبار الاتصال من Flutter
```

---

## ملاحظات مهمة

### 🔐 الأمان
- الـ `anon key` آمن في Flutter لأن الـ RLS بيحميك
- الـ `service_role key` لا يُستخدم أبدًا في Flutter
- استخدم `--dart-define` أو `.env` لحفظ الـ keys بأمان

### 🔁 لكل شيخ جديد
1. مشروع Supabase جديد مستقل
2. نفس هذه الخطوات بالكامل من البداية
3. تغيير `Project URL` و `anon key` في كود Flutter

---

*نهاية الدليل — الإصدار 1.0*
