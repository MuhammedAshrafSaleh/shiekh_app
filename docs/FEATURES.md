# Sheikhy (شيخي) — Feature Overview

---

## Why This Is Not YouTube

YouTube is a **public video platform** built for viral content, not for structured Islamic education. Here is what you get with YouTube that you do not want, and what you get with Sheikhy that you cannot get anywhere else.

| | YouTube | Sheikhy |
|---|---|---|
| Your content alongside inappropriate videos | Yes | Never |
| Ads interrupting your lessons | Yes | Never |
| Students distracted by recommended videos | Yes | Never |
| Your brand, your color, your name | No | Yes — fully yours |
| Student progress tracking | No | Full per-lesson + per-book |
| Lesson quizzes and final exams | No | Built in |
| Certificates with student names | No | Auto-generated PDF |
| Students can ask you questions | No | Integrated Q&A |
| You see who is studying and how far | No | Per-book analytics dashboard |
| You can push notifications to all students | No | Yes — broadcasts, live stream alerts |
| Students receive certificates they can download | No | Yes |
| Content organized into scientific disciplines | No | Yes — sections you define |
| Students enroll in books, not just watch videos | No | Yes — structured enrollment |
| Resume exactly where you left off | Sometimes | Always — per-second position saved |
| Works offline (audio + PDF) | No | Yes — downloaded locally |
| No hosting cost | Free with ads | Free, no ads, ever |
| Timestamped personal notes on any lesson | No | Yes — tap to jump back to exact second |
| Self-paced custom review exam | No | Yes — «اختبر نفسك» from any set of lessons |
| AI-generated quiz questions | No | Yes — Gemini drafts full MCQ sets in seconds |
| Browse without signing up | Limited | Yes — full guest browsing, gated on action |

**The core difference:** YouTube distributes content. Sheikhy delivers structured, accountable Islamic education — the kind that results in real learning, real certificates, and a real relationship between a sheikh and his students.

---

## What the Sheikh Gets

### Your App, Your Brand
Every deployment is exclusively yours. Your name, your chosen color scheme, your logo on the splash screen. No other sheikh's content ever appears in your app. When a student downloads it, it is your app — not a platform you happen to use.

### Publish Content Without Hosting It
You do not manage servers, upload videos, or pay bandwidth bills. Paste a YouTube link for video. Paste a Google Drive link for audio. Paste a Google Drive link for a PDF. Your app handles the rest — including converting links, managing downloads, and caching content for offline use. The entire platform runs at zero hosting cost.

### Organize by Scientific Discipline
Create your own **scientific sections** — عقيدة, فقه, تفسير, حديث, or whatever your curriculum requires. Each section has its own icon. Students browse and discover your content the way a serious student of knowledge would — by discipline, not by trending algorithm.

### Know Exactly Who Is Learning
Your **per-book analytics dashboard** shows:
- How many students enrolled
- Average exam score with a star rating
- Lesson-by-lesson completion rates
- Enrollment trend chart over time

This is information YouTube will never give you.

### Create Assessments That Matter
Author **per-lesson quizzes** and a **comprehensive final exam** for every book. Set the passing grade, the time limit, and how many attempts students get. The exam is graded server-side — students never see the correct answers before they submit. On passing, a certificate is automatically issued with the student's name, the book title, the date, their score, and their grade label.

### Answer Questions From Your Students
Students ask questions directly inside a lesson. You see them in your admin inbox with the student's identity. You reply inline. The answer is published back to all students of that lesson — anonymously attributed, to protect privacy. You are building a living body of knowledge around your curriculum.

### Broadcast to Your Students
Send notifications to your entire student base — new lesson announcements, live stream links, reminders. Students receive them in-app (and optionally via push). You reach everyone, instantly.

### Manage Everything From Your Phone
Your admin area travels with you. Add a book, paste lesson links, publish a quiz, check your stats, answer a question — all from the same app your students use, with a dedicated admin view.

---

## What the Student Gets

### One Place for Everything
No more jumping between YouTube, Telegram, WhatsApp PDFs, and scattered files. Every lesson — video, audio, and PDF — is in one place, organized by book and section, under one sheikh they trust.

### Real Progress, Not Just Views
Every lesson has a progress bar. Every book has a completion percentage. Students see exactly how far they have come and exactly what is left. The app resumes video and audio at the exact second they left off.

### Offline Access
Audio lessons are downloaded to the device. PDF documents are available in-app. Students can study on a bus, a plane, or anywhere without a connection. If they already downloaded a file, they never need to download it again.

### Certificates They Can Share
After passing a final exam, students receive a downloadable PDF certificate with their name, the book name, the date, and their score. This is a tangible result of real study.

### An Achievements Screen That Motivates
Students see a GitHub-style activity heatmap of their daily study, their total study hours (calculated from actual lesson durations, not estimates), completed books, and all their earned certificates — in one motivational screen.

### A Direct Line to the Sheikh
Students ask questions inside lessons. Anonymously to their peers, but fully identified to you. They receive a notification when you answer. This is the closest thing to a real student-sheikh relationship that a mobile app can offer.

### Light and Dark Mode, Full Arabic RTL
The app is built from the ground up for Arabic, right-to-left, with full light and dark theme support. It is calm, clean, and respectful — designed for a student of Islamic knowledge.

---

## White-Label: One Codebase, Any Sheikh

The same application can be deployed for any new sheikh in a few hours:
1. A new Supabase project (the database backend — free tier)
2. Change the sheikh name and primary color in the build configuration
3. Rebuild with the new credentials

No student data, no content, and no configuration is ever shared between deployments. Each sheikh gets a completely independent app.

---
---

## Technical Feature List

### Infrastructure & Architecture
- Flutter (iOS + Android), white-label via `--dart-define` build config (`SHEIKH_NAME`, `PRIMARY_COLOR`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- Supabase backend: PostgreSQL + RLS + Auth + Realtime; anon key only in client, service_role never exposed
- BLoC/Cubit state management (`flutter_bloc`); full `ExamBloc` with timer events, all other screens use Cubit
- GoRouter with role-based redirects: unauthenticated → `/login`, `student` → `/home`, `admin` → `/admin`
- Feature-first folder structure; Repository pattern; `Either<Failure, T>` (`dartz`) on every repo method
- `RepositoryProvider` DI tree (no `get_it`/`injectable`)
- Companion migration (`0001_app_support.sql`): 3 student-safe views, `submit_final_exam` RPC (SECURITY DEFINER), `grade_lesson_quiz` RPC, tightened RLS policies

### Authentication
- Email + password only (no OAuth); terms checkbox mandatory on sign-up
- Email confirmation support (handles both ON/OFF)
- `on_auth_user_created` trigger auto-creates `public.users` row with `role = 'student'`
- Forgot password with 45-second resend cooldown and neutral confirmation message (anti-enumeration, CC-30)
- Deep link `io.sheikhy.app://reset-callback` for password reset flow
- Admin role promoted manually via SQL; never through the app UI
- Role-based routing after every session restore

### Student Shell
- 4-tab persistent bottom nav: الرئيسية / المسار / إنجازاتي / حسابي
- `AuthCubit` drives all routing; `ThemeCubit` (persisted in SharedPreferences); `ConnectivityCubit` (offline detection)
- `OfflineBanner` wired to both student and admin shells via router

### Home Screen
- Banner carousel from `home_banners` (`is_active = true`, ordered by `order_index`); `carousel_slider`
- Featured books list from `books` (`is_featured = true AND status = 'published'`, ordered by `featured_order`) with per-student progress bars
- Banner tap navigates to linked book or opens external URL
- Graceful hidden/default state when no banners are active

### Path Screen (المسار)
- "جارية الآن" / "لم تبدأ بعد" tabs
- "Continue" card deep-links to the specific lesson via `lesson_progress.last_position_seconds`
- In-progress book list with progress bars; entry point to Scientific Sections grid

### Scientific Sections & Books
- 2-column sections grid; counts of published books per section; 8 fixed icon identifiers
- Books-of-section list: published only, optional search, progress bars (green = in-progress, gold = 100%)
- Both screens handle empty state with Arabic message + action button

### Book Details & Enrollment
- Cover image, title, description, overall progress bar
- Numbered lesson list with complete/in-progress/locked states
- Locked Final Exam card (unlocks when all lessons complete + exam published)
- Explicit enrollment via confirmation `AlertDialog`; `enrollments` insert with conflict-ignore (idempotent, CC-19)
- Button state: "تسجيل في الكتاب" → "استمرار المذاكرة" persisted across sessions
- Lesson access gated on enrollment (CC-20)
- CC-2: unpublished book shows "هذا المحتوى غير متاح حاليًا" overlay; enrollment row preserved

### Lesson Screen
- 4-tab shell: فيديو / صوت / PDF / اختبار; defaults to first available tab
- "اسأل سؤالك" entry opens Q&A bottom sheet; "الدرس التالي" button

#### Video Tab
- `youtube_player_iframe` for YouTube Unlisted videos
- `last_position_seconds` upserted to `lesson_progress` for resume
- Graceful error on deleted/private video (CC-6); other tabs remain usable

#### Audio Tab
- Google Drive share link → `drive_url.dart` → direct download URL (`uc?export=download&id=…`)
- `dio` download with progress indicator + cancel support
- Local cache check before re-downloading (CC-9/CC-10)
- `just_audio` + `audio_session` playback from local file
- Partial file discarded on interrupted download; never plays corrupt file (CC-9)
- Graceful quota-exceeded error with local-copy fallback (CC-7)
- Storage permission via `permission_handler`

#### PDF Tab
- `pdfx` in-app PDF viewer from Drive direct-download URL
- Graceful error for private/misconfigured links (CC-8)

#### Quiz Tab
- Questions fetched from `lesson_quiz_questions_student` view (no `correct_choice` exposed, CC-18)
- `grade_lesson_quiz` RPC for server-side grading with immediate feedback
- MCQ UI with `McqOptionCard` widgets

### Lesson Progress & Completion
- `lesson_progress` upserted on `(user_id, lesson_id)` — sets `completed`, `last_position_seconds`, `completed_at`
- Completion rule: ~90% of primary medium consumed OR "الدرس التالي" tapped, AND quiz answered if present
- Book completion % computed against currently-published lessons only (CC-21)
- Cascade-safe: deleted lesson → progress rows cascade-delete; % recomputes (CC-1)

### Q&A System (Student)
- Question submission via bottom sheet with privacy notice + character counter
- Inserts to `student_questions` with `status = 'pending'`, linked to `lesson_id` + `book_id`
- Student-facing queries use `student_questions_public` view (no `user_id` exposed, CC-22)
- Answered questions show sheikh's reply; pending show "بانتظار الرد" badge
- Asker anonymized to peers ("طالب" + relative time)
- Book-level Q&A screen aggregates all questions for a book with lesson sub-label

### Final Exam (Student)
- `ExamBloc` with events: `Started`, `AnswerSelected`, `NavigatedTo`, `Tick`, `Submitted`, `AutoSubmitted`, `Resumed`
- Exam Intro: question count, time, pass %, attempt count, lock state (CC-13/CC-15/CC-16), past-attempts link
- In-progress: red countdown timer (last minutes), question navigator grid (answered vs. unanswered), prev/next, MCQ via `final_exam_questions_student` view
- Submit confirmation modal warns about unanswered questions
- Single `submit_final_exam(p_book_id, p_answers, p_started_at)` RPC: SECURITY DEFINER, enforces attempt limit, grades server-side, inserts attempt + certificate ON CONFLICT DO NOTHING, grade label banding (≥90 ممتاز / ≥80 جيد جداً / else جيد), sends achievement notification
- Auto-submit on timer expiry (CC-12); resume-or-auto-submit on app reopen (CC-11) via `SharedPreferences`-persisted start time
- Result screen: circular score ring, correct count, certificate preview, download/back

### Certificates
- Auto-generated on passing attempt via `submit_final_exam` RPC (never client-side)
- Client-side PDF generation via `pdf` + `printing` packages
- Contains: student name, book title, issue date, score percentage, grade label
- Unique per `(user_id, book_id)`; shareable/saveable
- Listed in Achievements screen and Profile → شهاداتي

### Achievements Screen
- 3 stat cards: completed lessons, study hours (via `get_my_study_seconds()` RPC — sums actual lesson durations), completed books
- Activity heatmap: `flutter_heatmap_calendar`, 4 shading levels, daily activity events (progress records + exam attempts)
- Certificates list with download buttons
- Empty state encourages completing first book
- Both achievements page and certificates gated behind account (guest conversion CTA for unauthenticated users)

### Profile & Account
- Initials avatar (no photo upload by design); name, email display
- 3 quick stats inline
- Menu: شهاداتي / تغيير كلمة المرور / الوضع الليلي toggle / عن التطبيق / تسجيل الخروج
- Edit Profile: editable full name; read-only email (lock icon); optional change-password section (requires current password verification)
- Logout confirmation `AlertDialog`
- Guest-aware profile menu with "إنشاء حساب" CTA for unauthenticated users

### Notifications (Student)
- Uniform cards for all types (live stream, new lesson, reminder, achievement); no special per-type styling
- Unread indicator: dot + lighter card background
- Full-card tap → deep-link to `link_url` if present → marked read
- "تحديد الكل كمقروء": bulk insert `notification_reads` rows for all unread
- Realtime Supabase channel subscription for live updates (one of exactly two Realtime surfaces in the app)
- Read state tracked in `notification_reads` table

### Admin Shell
- 2-tab bottom nav: لوحة التحكم / الإعدادات; gold active pill
- Separate `ShellRoute` from student shell
- `OfflineBanner` wired identically to student shell

### Admin Dashboard
- Live stat cards: lesson count, book count, certificates granted, student count
- 3 quick actions: إضافة قسم جديد / إضافة كتاب جديد / إضافة إشعار جديد
- "كتبي" list with edit/delete, dual-axis status badges (status + review_status)
- Strong delete warning for books with enrollments/progress/certificates (CC-4)

### Admin Section Management
- Create/edit/delete sections: name, fixed 8-icon picker, optional description
- Section list with book counts
- Delete blocked with clear Arabic error if section has books (`on delete restrict`, CC-3)

### Admin Book Management
- Cover image (`cached_network_image` / `image_picker`, public `media` Storage bucket), title, description, section dropdown
- Featured toggle + manual `featured_order`; non-blocking warning if >5 featured (CC-24); DB trigger `enforce_featured_cap` auto-drops if exceeded (CC-25)
- Dual status axes: `status` (draft/published) controls student visibility; `review_status` (in_review/completed) is internal admin indicator only
- "حفظ ومتابعة لإضافة الدروس" → opens Book Dashboard

### Admin Book Dashboard (Per-Book)
- Tabbed: الدروس / الإحصائيات / الأسئلة / الإعدادات
- Lessons tab: combined scrollable dashboard — lesson list (drag-to-reorder via `reorder_lessons` RPC, atomic CC-5), publish toggles, stats summary (completion %, enrolled students, avg score + star visualization, enrollment trend `fl_chart`), 2 most-recent questions preview
- Questions tab: "بانتظار الرد" / "تم الرد عليها" tabs; Realtime subscription (second Realtime surface); inline reply → sets `status = 'answered'` + notifies asker; full student identity visible to admin
- Statistics: `fl_chart` bar/line charts for enrollment trend and score distribution
- Final Exam card entry

### Admin Lesson Management
- 4 tabs: فيديو / صوت / PDF / أسئلة
- Video tab: YouTube link field + auto-preview + "نشر الدرس مباشرة" switch; admin enters `video_duration_minutes` manually (1–600, nullable)
- Audio tab: Google Drive link field + audio player preview + "هذا الدرس صوت فقط" switch; admin enters `audio_duration_minutes` manually (1–600, nullable)
- PDF tab: Google Drive link field + public-sharing reminder + file preview
- Quiz tab: question list with text, 4 choices, correct-answer marker; edit/delete
- **Unified save:** single sticky "حفظ الدرس" button saves all 4 tabs as one Supabase record regardless of active tab
- Transactional `reorder_lessons` RPC for drag reorder (CC-5)

### Admin Final Exam Management
- Settings: time limit (minutes), passing percentage (%), allowed attempts; settings apply to future attempts only (CC-14)
- Question authoring: text + 4 choices + mark correct; reorderable list
- Optional import from lesson question bank (`source_quiz_question_id` reference)
- "معاينة الاختبار كما يراه الطالب" preview
- "حفظ ونشر الاختبار" sets `is_published = true`
- Zero-question lock: students cannot start; admin sees warning (CC-16)

### Admin Notifications
- 4 types: general / live_stream / new_lesson / reminder
- Title, body (char counter), optional link, live-stream link field (conditional on type)
- Immediate send or scheduled (`send_at`)
- Live preview
- Persists to `notifications`; optional FCM delivery via Edge Function or DB webhook (topic `students`)

### Admin Banner Management
- Add/edit/delete banners: image, title, description, linked book or external URL, `order_index`, `is_active`
- Graceful null-link handling: if linked book deleted, `linked_book_id` set null; banner shows "المحتوى غير متاح" (CC-26)

### Offline & Connectivity
- `ConnectivityCubit` via `connectivity_plus`; `OfflineBanner` in both shells
- Exam start blocked when offline; other cached/downloaded content remains accessible (CC-10)
- Network-dependent screens show friendly offline state, not crash

### Security
- RLS enforced on all 15 tables (schema.sql + companion migration)
- `correct_choice` never returned to student clients; only via `is_admin()` policy or `_student` views (CC-18)
- `student_questions_public` view strips `user_id` for student queries (CC-22)
- `submit_final_exam` is SECURITY DEFINER — all grading, attempt counting, and certificate issuance is server-side only
- `service_role` key never referenced in `lib/`
- Supabase credentials stored via `--dart-define`, never hardcoded

### Theming & Localization
- Light + dark themes; `ThemeCubit` persisted in `SharedPreferences` key `app_theme`
- `ColorScheme.fromSeed(seedColor: AppConfig.primaryColor)` for both themes
- Cairo font (`google_fonts`); Amiri (headings) + Tajawal (body) for PDF certificate generation
- Single locale: Arabic (`Locale('ar')`), full RTL
- `EdgeInsetsDirectional` and `AlignmentDirectional` throughout (no left/right variants)
- All spacing from `AppSpacing` constants; all font sizes from `textTheme`

### Performance
- `ListView.builder` on all variable-length lists; pagination on large collections
- `BlocSelector` for single-field rebuilds; `const` widgets throughout
- `.limit()` on all unbounded Supabase queries; server-side filtering + sorting
- `RepaintBoundary` around exam timer and charts
- Audio downloaded once, local cache reused on re-entry
- Realtime subscriptions on exactly two surfaces only; everything else is explicit refetch + pull-to-refresh
- Realtime subscriptions cancelled in `Cubit.close()` / `Bloc.close()`

### White-Label Deployment
- Redeploy for any new sheikh: new Supabase project → run schema + migration → `--dart-define` with new credentials + name + color → rebuild
- `docs/WHITELABEL.md`: 10-step guide + checklist
- `docs/admin_recovery.sql`: SQL for admin account recovery (CC-29)
- No cross-deployment data coupling; each deployment is fully isolated

### Guest Mode
- Unauthenticated browsing via Supabase anonymous auth
- Achievements, certificates, Q&A ask, exam gated behind account
- Guest conversion CTA in profile menu and gated screens
- Lesson entitlement logic with RLS (migration 0007)

### Notes (الملحوظات)
- Students add timestamped notes while watching video or listening to audio; playback pauses automatically on note creation
- Notes stored in `lesson_notes` table, linked to `(user_id, lesson_id, position_seconds)`
- Book-level **المحفوظات** tab lists all notes for a book sorted by lesson/time; tap any note → navigates into the lesson and seeks to the exact second (video or audio)
- In-lesson notes list rendered below the player (video + audio tabs) via `CustomScrollView` slivers; add/edit/delete refresh in real-time without leaving the tab
- `NotesCubit` supports both book-scope (المحفوظات tab) and lesson-scope (in-tab list); `NoteCard.onSeek` callback seeks the local player instead of navigating when rendered inside a lesson tab
- Guest gate: note creation prompts sign-up with `returnTo` + `autoEnrollBookId` params

### Practice Exams (اختبر نفسك)
- New raised circular center button in the 5-tab student bottom nav: الرئيسية · مساري · **اختبر نفسك** · إنجازاتي · حسابي
- **Setup screen:** lessons grouped by book (accordion + select-all); only lessons with a submitted quiz are eligible; question count slider (min 20, max `min(100, available)`); optional timer (15–120 min, step 5 min); blocked with «اختار محاضرات أكتر» CTA when < 20 questions available
- **Question distribution** (pure, unit-tested): even split across lectures, random remainder, short-lecture backfill, per-question shuffle; choices always displayed a/b/c/d
- **Loading screen:** cycles admin-managed motivational quotes (~3 s each with progress bar); «ابدأ الآن» appears after first quote; question pool prefetched in parallel so exam opens instantly; falls back to 3 seeded defaults when no quotes are active
- **Exam runner:** MCQ + question-map navigator, optional wall-clock timer with auto-submit on expiry, leave-confirmation dialog (nothing saved), failed-submit retains answers + retry, double-submit guard
- **Result + history:** total score, per-lecture breakdown, per-question review (reuses shared quiz-review widget with source-lecture label); last 10 attempts kept; tapping any attempt reopens its full review
- **Security:** no client-side writes; only write path is `submit_practice_attempt` RPC (SECURITY DEFINER); questions fetched from `lesson_quiz_questions_student` view (no `correct_choice` exposed, CC-18); `correct_choice` returned only by grading/review RPCs after submission
- **Migration:** `0020_practice_exams.sql` — `practice_attempts` table (select-own RLS; inserts via RPC), keep-last-10 trigger, `loading_quotes` table + 3 seeded defaults, RPCs: `get_practice_eligible_lessons`, `submit_practice_attempt`, `get_practice_attempt_review`

### Admin AI Question Generation
- Admin can store their own Gemini API key via Settings screen (stored in `app_secrets` table, `SECURITY DEFINER` RPCs, never exposed to client in plaintext)
- From the quiz tab of any lesson, admin pastes lecture text → Gemini generates a full set of MCQ questions ready to review and publish
- Animated multi-step progress bar during generation; AI overload (deadline_exceeded) maps to `AiOverloadFailure` with a midnight-retry hint in the UI
- Migration `0023`: `revoke execute on app_secrets RPCs from public/anon` for hardened key storage

### Admin Loading-Quotes CRUD
- Accessible from Admin Dashboard tile and `/admin/loading-quotes` route
- List view with drag-reorder (persisted via `order_index`), per-row active toggle, edit, delete (shared confirm dialog)
- Add/Edit form: text required ≤ 200 chars (live counter); optional source attribution ≤ 60 chars
- Info banner shown when no quotes are active; student loading screen falls back to 3 seeded defaults
