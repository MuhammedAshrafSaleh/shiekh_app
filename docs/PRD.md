# Product Requirements Document (PRD)
## Sheikhy (شيخي) — Islamic Educational Platform

**Version:** 1.0
**Status:** Ready for Implementation
**Primary Audience:** Claude Code (Flutter implementation)
**Related Documents:** `BRD.md`, `schema.sql`, `Supabase_Setup_Guide.md`

---

## Table of Contents

1. Product Overview
2. User Roles & Personas
3. Authentication System
4. Feature Requirements
5. User Flows
6. Corner Cases & Edge Cases
7. Non-Functional Requirements
8. Out of Scope (Backlog)

---

## 1. Product Overview

### 1.1 Vision

Sheikhy is a **white-label mobile application template** that enables a single Islamic scholar (sheikh) to publish structured educational content — books, lessons, quizzes, and exams — to their students, with zero hosting costs. Each deployment serves exactly **one sheikh**; it is not a multi-tenant marketplace.

### 1.2 Core Value Proposition

- **For the Sheikh:** A ready-made, professional app to publish and organize their teaching, track student engagement, answer questions, and issue certificates — without technical overhead or hosting fees.
- **For the Student:** A structured, distraction-free learning environment with progress tracking, interactive quizzes, direct access to the sheikh's answers, and earned certificates.

### 1.3 Template / White-Label Nature

This is a **reusable product template**. Every architectural, schema, and code decision must remain clean and repeatable so the same codebase can be redeployed for a new sheikh by:
1. Creating a fresh Supabase project (running the same schema)
2. Changing customization variables (sheikh name, primary color)
3. Rebuilding with new Supabase credentials

No student data, content, or configuration is ever shared between sheikh deployments.

### 1.4 Platforms

- **Primary:** Flutter mobile app (Android & iOS)
- **Future:** Web version via the same Flutter codebase (`flutter build web`) — see Backlog

### 1.5 Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Client | Flutter | Cross-platform, RTL Arabic UI |
| Backend | Supabase (PostgreSQL) | Auth, database, RLS |
| Video hosting | YouTube (Unlisted) | Progressive streaming, no bandwidth cost |
| Audio hosting | Google Drive | Download-then-play locally |
| PDF hosting | Google Drive | Public share link |
| Push notifications | Firebase Cloud Messaging (FCM) | Separate from Supabase |

### 1.6 Design Language

- Full Arabic UI, right-to-left (RTL)
- Light and dark theme support
- Primary color is a customization variable per deployment (reference designs use dark green)
- Calm, respectful, education-focused aesthetic

---

## 2. User Roles & Personas

### 2.1 Role Model

The system has exactly **two roles**, stored in `public.users.role`:
- `student` — content consumer (the default for all self-registrations)
- `admin` — the sheikh (content manager); promoted manually via SQL

Both roles authenticate through the **same login system**. Routing after login is determined by the `role` field.

### 2.2 Persona: The Student

**Profile:** A learner seeking structured Islamic knowledge from a specific trusted scholar.

**Goals:**
- Find and study books organized by scientific discipline
- Track their own progress and pick up where they left off
- Test their understanding through quizzes and exams
- Earn certificates that validate completion
- Ask the sheikh questions and read answers to others' questions

**Pain Points the App Solves:**
- Scattered content across YouTube/Telegram/PDFs → unified in one place
- No sense of progress or completion → progress bars, heatmap, certificates
- No way to ask questions → integrated Q&A

**Journey:** Register → Browse sections → Enroll in a book → Study lessons (video/audio/PDF) → Take lesson quizzes → Complete book → Pass final exam → Receive certificate.

### 2.3 Persona: The Sheikh (Admin)

**Profile:** An Islamic scholar who wants to reach students digitally without technical complexity.

**Goals:**
- Publish books and lessons easily by pasting links (no video uploads to manage)
- Organize content into scientific sections
- Author quizzes and final exams
- Monitor student engagement per book
- Answer student questions
- Broadcast notifications (including live streams)

**Pain Points the App Solves:**
- Technical hosting complexity → just paste YouTube/Drive links
- No engagement visibility → per-book statistics dashboard
- No structured way to assess students → quiz and exam authoring tools

**Journey:** Log in → Dashboard → Create sections → Create books → Add lessons with content links → Author quizzes and exams → Publish → Monitor stats and answer questions.

---

## 3. Authentication System

### 3.1 Method

- **Email and password only.** No Google, Apple, or other third-party providers.
- No guest mode in the current scope (registration is mandatory).

### 3.2 Screens

1. **Splash Screen** — sheikh logo, app name, "تحت إشراف اللجنة العلمية" subtitle, loading indicator.
2. **Login** — email, password (with show/hide toggle), "forgot password" link.
3. **Sign Up** — full name, email, password, confirm password, mandatory terms-acceptance checkbox.
4. **Forgot Password** — email field only.
5. **Reset Link Sent Confirmation** — success state, "open email app" button, "resend" with 45-second cooldown countdown.

### 3.3 Business Rules

- Terms & privacy acceptance is **mandatory** before sign-up completes.
- Password reset link is time-limited (Supabase default ~60 min).
- Resend button has a cooldown to prevent spam.
- On registration, a `public.users` row is auto-created with `role = 'student'` via the `handle_new_user` database trigger.
- The sheikh's account is promoted to `admin` manually via SQL (never through the app UI).
- After login, the app reads `role` and routes to either the student UI or the admin dashboard.

### 3.4 Acceptance Criteria

- A user cannot complete sign-up without checking the terms box.
- A newly registered user lands in the student experience.
- An admin user lands in the admin dashboard.
- Invalid credentials show a clear inline Arabic error message.
- The email field on the profile edit screen is read-only (identity is tied to auth).

---

## 4. Feature Requirements

Each feature below is written with a description, user stories, acceptance criteria, and business rules where relevant.

---

### 4.1 Home Screen (Student)

**Description:** The student's landing screen after login. A fast, promotional surface — NOT the primary navigation hub.

**Contents:**
- Top bar: greeting with student's name, notification bell icon, small avatar (initials-based)
- Banner carousel (managed entirely from the Admin "Banner Management" screen)
- "أهم الكتب" (Featured Books) list — books the admin flagged as featured, in the admin's manual order, each with a progress bar
- Bottom navigation bar (4 items): الرئيسية / المسار / إنجازاتي / حسابي

**User Stories:**
- As a student, I want to see highlighted courses and important announcements immediately so I know what's new and relevant.
- As a student, I want to see my featured books with progress so I can quickly resume.

**Acceptance Criteria:**
- Banner carousel pulls from `home_banners` where `is_active = true`, ordered by `order_index`.
- Featured books pull from `books` where `is_featured = true AND status = 'published'`, ordered by `featured_order`.
- Tapping a banner navigates to its `linked_book_id` or opens its `external_link`.
- If no banners are active, the carousel area is gracefully hidden or shows a default.

**Business Rules:**
- The Home screen is for quick/promotional display only. Hierarchical browsing happens in "المسار".

---

### 4.2 Path Screen (المسار)

**Description:** The primary navigation hub for organized content. Shows ongoing lessons AND provides entry to the scientific sections.

**Contents:**
- "جارية الآن" / "لم تبدأ بعد" tabs
- A prominent "continue where you left off" card for the last-opened book (deep-links to the exact lesson)
- List of other in-progress books with progress bars
- Entry point to the Scientific Sections screen
- Empty state when the student hasn't started any book

**User Stories:**
- As a student, I want to resume my most recent lesson with one tap.
- As a student, I want to browse all content organized by scientific discipline.

**Acceptance Criteria:**
- "Continue" card deep-links to the specific lesson via `lesson_progress.last_position_seconds`.
- In-progress books are those with at least one `lesson_progress` record but not 100% complete.
- Empty state guides the student to browse sections.

---

### 4.3 Scientific Sections (الأقسام العلمية)

**Description:** A grid of content categories (عقيدة, فقه, تفسير, etc.), accessed from the Path screen.

**Contents:**
- 2-column grid of section cards (icon in a circle, name, book count)
- Tapping a section opens the "Books of Section" screen

**Acceptance Criteria:**
- Each card shows the count of published books in that section.
- Icons come from a fixed icon set (stored as `sections.icon` string identifier).
- Empty state if no sections exist.

---

### 4.4 Books of a Section

**Description:** Lists all published books within a selected section.

**Contents:**
- Section title + book count + optional search bar
- Vertical list of book cards (cover, title, lesson count, progress bar if started)

**Acceptance Criteria:**
- Only `status = 'published'` books appear.
- Progress bar reflects the student's completion for books they've started.

---

### 4.5 Book Details + Enrollment

**Description:** The detail view of a single book, including its lessons and the enrollment mechanism.

**Contents:**
- Cover image, title, description, overall progress bar
- Numbered lesson list (completed check / locked state)
- "الاختبار الشامل" (Final Exam) card at the end of the list
- **Enrollment button:** On first visit, shows "تسجيل في الكتاب" instead of "استمرار المذاكرة". Tapping it opens a Confirmation Dialog. After confirmation, an `enrollment` record is created and the button becomes "استمرار المذاكرة".

**User Stories:**
- As a student, I want to explicitly enroll in a book so my intent is clear and my progress is tracked.
- As a sheikh, I want accurate enrollment counts (real enrollments, not casual views).

**Acceptance Criteria:**
- Enrollment creates a unique `enrollments` row (`user_id`, `book_id`).
- The Confirmation Dialog names the specific book.
- After enrollment, the button state persists across sessions.
- The Final Exam card is locked until all lessons are completed.

**Business Rules:**
- Enrollment is explicit and confirmed — never automatic on view.

---

### 4.6 Lesson Screen

**Description:** The core content consumption screen, organized into four tabs.

**Contents:**
- Video player at top
- Lesson title + description
- **Four tabs (RTL order): فيديو / صوت / PDF / اختبار**
- Quick "اسأل سؤالك" entry (opens Q&A bottom sheet)
- "الدرس التالي" button

**Tab behaviors:**
- **فيديو (Video):** YouTube player (Unlisted video via `youtube_player_iframe`). Progressive streaming. Default active tab.
- **صوت (Audio):** Google Drive audio via download-then-play. Shows a "download" button; on tap, downloads the file locally, then plays with a local audio player. Checks if already downloaded before re-downloading.
- **PDF:** Google Drive PDF link, opened/viewed in-app.
- **اختبار (Quiz):** The short per-lesson quiz.

**Acceptance Criteria:**
- Each tab is optional; a lesson may have only some content types.
- Video position is saved to `lesson_progress.last_position_seconds` for resume.
- A lesson is marked complete when its content is consumed and quiz (if any) is answered.
- Audio download requires storage permission; re-entry reuses the local file.

**Business Rules:**
- All four content types belong to ONE lesson record. (See Admin unified save, 4.19.)

---

### 4.7 Lesson Quiz

**Description:** A short quiz specific to each lesson, using the same UI pattern as the final exam.

**Contents:**
- Multiple-choice questions (4 choices each)
- Timer, question numbering
- Immediate feedback

**Acceptance Criteria:**
- Questions come from `lesson_quiz_questions` for that lesson.
- The correct answer must NOT be exposed to the client before the student answers (fetch without `correct_choice`, or validate server-side).

**Business Rules:**
- The lesson quiz is separate from both the Q&A and the final exam.

---

### 4.8 Q&A System (Student Side)

**Description:** Students ask questions in a lesson's context; the sheikh's answers are visible to all students of that lesson.

**Contents:**
- Bottom sheet to enter a question (from within a lesson)
- "سيظهر سؤالك وإجابته لجميع طلاب هذا الدرس" notice
- Character counter

**User Stories:**
- As a student, I want to ask the sheikh a question about a lesson.
- As a student, I want to read answers to other students' questions to avoid duplicates.

**Acceptance Criteria:**
- A question is created in `student_questions` with `status = 'pending'`, linked to both `lesson_id` and `book_id`.
- **Privacy: The asker's identity is ALWAYS hidden from other students** (shown as "طالب" + relative time). It is ALWAYS visible to the admin.
- When the sheikh answers, the asking student receives a notification.

**Business Rules:**
- Question input is per-lesson; answers are visible to all students of that lesson.

---

### 4.9 Book-Level Q&A Screen

**Description:** Aggregates all questions from all lessons of a book into one screen (accessed from Book Details).

**Acceptance Criteria:**
- Lists all `student_questions` for the book, each showing its related lesson name as a sub-detail.
- Answered questions show the sheikh's reply; pending ones show a "بانتظار الرد" badge.
- Asker identity remains anonymized to students here as well.

---

### 4.10 Final Exam (Student Side)

**Description:** The comprehensive book exam, unlocked after completing all lessons.

**Screens:**
1. **Exam Intro:** question count, time available, passing percentage, "ابدأ الاختبار" button, "عرض محاولاتي السابقة" link.
2. **Exam In Progress:** timer (turns red in final minutes), question counter, progress bar, multiple-choice cards, **question navigator grid** (answered vs. unanswered), previous/next buttons.
3. **Submit Confirmation:** modal warning about unanswered questions, "مراجعة الأسئلة" / "تسليم الاختبار".
4. **Result & Certificate:** circular score, correct-answer count, certificate preview, "تحميل الشهادة" / "العودة للكتاب".

**User Stories:**
- As a student, I want to know the exam rules before starting.
- As a student, I want to navigate freely between questions.
- As a student, I want to see my past attempts.

**Acceptance Criteria:**
- Exam unlocks only when all lessons are complete AND the exam is published (`final_exam_settings.is_published = true`).
- Questions come from `final_exam_questions`; `correct_choice` is not exposed pre-submission.
- Each submission creates a `final_exam_attempts` row with `attempt_number`, `score_percentage`, `passed`, and `answers` JSON.
- Attempt count is enforced against `final_exam_settings.max_attempts`.
- On passing, a `certificates` row is generated (unique per user+book).

**Business Rules:**
- Exam questions are authored by the sheikh (manually or imported from the lesson question bank).
- Max attempts is per-book, admin-configured (default 2).

---

### 4.11 Certificates

**Description:** Auto-generated proof of completion after passing a final exam.

**Acceptance Criteria:**
- Created automatically on a passing attempt.
- Contains student name, book title, issue date, final score, grade label.
- Downloadable as PDF (generated client-side or via link in `certificates.pdf_url`).
- One certificate per user per book (unique constraint).

---

### 4.12 Progress Tracking

**Description:** Tracks each student's progress per lesson and aggregates to book completion.

**Acceptance Criteria:**
- `lesson_progress` records completion and `last_position_seconds` per lesson.
- Book completion % = completed lessons / total published lessons.
- Resume returns the student to their last position.

---

### 4.13 Achievements Screen (إنجازاتي)

**Description:** Motivational screen with stats, an activity heatmap, and certificates.

**Contents:**
- Three stat cards: completed lessons, study hours, completed books
- Annual activity heatmap (GitHub-style, 4 shading levels)
- Certificates list (book name, date, final score, download button)

**Acceptance Criteria:**
- Heatmap reflects daily activity levels.
- Certificates list pulls from `certificates`.
- Empty state encourages completing the first book.

---

### 4.14 Profile Screen (حسابي)

**Description:** The student's account and settings hub.

**Contents:**
- Initials-based avatar (NO photo upload), name, email
- "تعديل الملف الشخصي" button
- Three quick stats
- List: شهاداتي, تغيير كلمة المرور, الوضع الليلي (switch), عن التطبيق, تسجيل الخروج

**Acceptance Criteria:**
- No profile photo upload feature (cost decision); avatar is generated from the first letter of the name.
- Dark mode toggles from here.

---

### 4.15 Edit Profile

**Description:** Edit name and change password.

**Contents:**
- Editable full name
- Read-only email (with lock icon)
- Separate "change password" section (current password + new + confirm)
- Single "حفظ التغييرات" button

**Acceptance Criteria:**
- Email is read-only (tied to auth identity).
- Changing password requires the current password for verification.
- The password section is optional (name can be saved without touching it).

---

### 4.16 Notifications (Student Side)

**Description:** A unified list of all notification types.

**Contents:**
- Header with "تحديد الكل كمقروء"
- Uniformly-styled cards for all types (live stream, new lesson, reminder, achievement) — NO special visual treatment per type
- Each card is fully clickable; unread cards have a dot indicator and lighter background

**Acceptance Criteria:**
- Notifications come from `notifications`; read state tracked in `notification_reads`.
- Live-stream notification links open its `link_url` (clickable full card).
- "Mark all read" inserts `notification_reads` rows for all unread notifications.

**Business Rules:**
- All notification types share identical card styling (no special live-stream banner).

---

### 4.17 Admin Dashboard

**Description:** The sheikh's landing screen.

**Contents:**
- Four stat cards: lesson count, book count, certificates granted, student count
- Three quick actions: إضافة قسم جديد, إضافة كتاب جديد, إضافة إشعار جديد
- "كتبي" list (each book with edit/delete, status badge)
- Bottom nav (2 items): لوحة التحكم / الإعدادات

**Acceptance Criteria:**
- Tapping a book opens its per-book Book Dashboard.
- Stat cards reflect live aggregate counts.

---

### 4.18 Admin Section Management

**Description:** Create and manage scientific sections.

**Contents:**
- Section name, icon picker (fixed set of ~8 icons), optional description
- "الأقسام الحالية" list with edit/delete and book counts

**Acceptance Criteria:**
- Icon is chosen from a fixed set (stored as identifier), not a custom upload.
- A section cannot be deleted if it has books (FK is `on delete restrict`).

---

### 4.19 Admin Book Management

**Description:** Add and edit books.

**Contents:**
- Cover image, title, description, section (dropdown)
- **"إظهار هذا الكتاب في الرئيسية" (featured) toggle**
- Manual featured ordering (drag or order number)
- "حفظ ومتابعة لإضافة الدروس" button

**Acceptance Criteria:**
- Book has two independent status axes: `status` (draft/published) and `review_status` (in_review/completed).
- Featured books have a manual `featured_order`.
- A recommended cap of 3-5 featured books with an admin warning if exceeded.

**Business Rules:**
- `status` controls student visibility; `review_status` is an internal admin indicator only.

---

### 4.20 Admin Book Dashboard (Per-Book)

**Description:** A dedicated control panel opened when the admin taps a specific book. Tabbed: الدروس / الإحصائيات / الأسئلة / الإعدادات.

**Lessons tab (combined dashboard-style view):**
- "إضافة درس جديد" button
- Lesson list (number, name, content-type icons, status badge, drag-to-reorder, edit/delete)
- Embedded statistics summary (completion %, total students, avg exam score with star rating, enrollment trend chart)
- Latest questions preview (2 most recent)
- Separate "الاختبار الشامل" card

**Questions tab:** Full screen with "بانتظار الرد" (count badge) / "تم الرد عليها" tabs; inline reply per card; student identity visible to admin.

**Acceptance Criteria:**
- The Lessons tab is a single scrollable dashboard combining lessons + stats + recent questions.
- Average exam score shown as percentage + star visualization.
- Admin sees full student identity in questions.

---

### 4.21 Admin Lesson Management

**Description:** Add and edit lessons with four content tabs.

**Contents:**
- Lesson name + four tabs: أسئلة / PDF / صوت / فيديو
- **Video tab:** YouTube link field + auto preview + "نشر الدرس مباشرة" switch
- **Audio tab:** Google Drive link field + audio player preview + "هذا الدرس صوت فقط بدون فيديو" switch
- **PDF tab:** Google Drive link field (with public-sharing note) + file preview
- **Quiz tab:** question counter + question list (text, 4 choices, correct marked) + edit/delete

**Acceptance Criteria:**
- **Unified save:** the lesson is ONE record; the "حفظ الدرس" button (sticky across all tabs) saves all tab data in one operation regardless of the active tab.
- Content sources: video → YouTube; audio & PDF → Google Drive.
- Publishing a lesson toggles its `status`.

**Business Rules:**
- The four tabs are UI organization, not separate save operations.

---

### 4.22 Admin Final Exam Management

**Description:** Configure and author the comprehensive book exam.

**Contents:**
- Settings: time limit (minutes), passing percentage (%), allowed attempts
- "إضافة سؤال جديد" + question list (reorderable)
- **Optional question bank import** from lesson quiz questions
- "معاينة الاختبار كما يراه الطالب" + "حفظ ونشر الاختبار"

**Acceptance Criteria:**
- Settings persist in `final_exam_settings`.
- Questions persist in `final_exam_questions`; imported ones reference `source_quiz_question_id`.
- Publishing sets `is_published = true`.
- If no questions exist, students cannot start the exam (warning shown to admin).

**Business Rules:**
- Questions authored manually OR imported from the lesson question bank (import is optional, not mandatory).

---

### 4.23 Admin Notifications

**Description:** Create and send notifications.

**Contents:**
- Type dropdown (general / live_stream / new_lesson / reminder)
- Title, body (char counter)
- Live-stream link field (shown when type = live_stream)
- Optional general link field
- "إرسال فوري الآن" switch (or schedule)
- Live preview
- "إرسال الإشعار" button

**Acceptance Criteria:**
- Notification persists in `notifications` with `send_at` (immediate or scheduled).
- The optional link maps to `link_url`.
- FCM delivery is triggered for the notification (see Non-Functional / backend note).

---

### 4.24 Admin Banner Management

**Description:** Manage the Home screen banner carousel.

**Contents:**
- Add/edit/delete banners
- Per banner: image/background, title, description, link (book or external), display order (drag)

**Acceptance Criteria:**
- Banners persist in `home_banners`.
- Order is manually controlled via `order_index`.
- `is_active` toggles visibility to students.

---

## 5. User Flows

### 5.1 Student Registration & Onboarding

1. Splash screen → Login screen
2. Student taps "سجل الآن" → Sign Up
3. Enters name, email, password, confirm password; checks terms
4. On submit: Supabase Auth creates account → `handle_new_user` trigger creates `public.users` row (`role = 'student'`)
5. (If email confirmation enabled) student confirms via email
6. Student lands on Home screen

### 5.2 Student Content Consumption

1. Home → tap "المسار" → Scientific Sections
2. Select a section → Books of Section
3. Tap a book → Book Details
4. Tap "تسجيل في الكتاب" → Confirmation Dialog → confirm → enrolled
5. Tap a lesson → Lesson Screen
6. Watch video / download audio / view PDF / take lesson quiz
7. Progress auto-saved; lesson marked complete
8. Repeat for all lessons
9. Final Exam unlocks → Exam Intro → take exam → submit
10. On passing → certificate generated → downloadable from Achievements

### 5.3 Admin Content Creation

1. Log in (admin) → Admin Dashboard
2. "إضافة قسم جديد" → create scientific section(s)
3. "إضافة كتاب جديد" → create book (assign section, optionally feature it)
4. On save → Book Dashboard → "إضافة درس جديد"
5. For each lesson: paste video link, audio link, PDF link, add quiz questions → "حفظ الدرس"
6. Reorder lessons via drag as needed
7. Open Final Exam management → set time/passing/attempts → add or import questions → "حفظ ونشر الاختبار"
8. Publish book (`status = published`)
9. Optionally set up banners and send a launch notification

### 5.4 Q&A Flow

1. Student (in a lesson) taps "اسأل سؤالك" → bottom sheet → submits question
2. Question created (`status = pending`), visible to admin with identity
3. Admin opens Book Dashboard → Questions tab → "بانتظار الرد"
4. Admin types inline reply → sends
5. Question `status = answered`; asking student notified
6. Answer becomes visible to all students of that lesson (asker anonymized to peers)

### 5.5 Notification Flow

1. Admin → "إضافة إشعار جديد" → chooses type, writes content, optional link
2. Sends immediately or schedules (`send_at`)
3. FCM delivers push to students
4. Notification appears in students' Notifications list (unread)
5. Student taps → opens link (if any) → marked read (`notification_reads`)

---

## 6. Corner Cases & Edge Cases

This section enumerates edge cases that MUST be handled. Each includes the required behavior.

### 6.1 Content Lifecycle

**CC-1 — Admin deletes a lesson with existing student progress.**
`lesson_progress` rows cascade-delete (FK `on delete cascade`). Book completion % recalculates against remaining lessons. Students previously "complete" may drop below 100%; this is acceptable. Do not crash any screen referencing the deleted lesson.

**CC-2 — Admin unpublishes a book a student is enrolled in.**
The book disappears from student browse/Home (RLS filters `status = 'published'`). The enrollment record persists. Decision: enrolled students should retain read access OR the book gracefully disappears from their Path with a message. RECOMMENDED: hide from new browsing but keep enrolled students' access via an enrollment-aware policy; if simpler, hide entirely and show "هذا المحتوى غير متاح حاليًا". Implementer must choose and document.

**CC-3 — Admin deletes a section that has books.**
Blocked by `on delete restrict`. UI must show a clear error: "لا يمكن حذف قسم يحتوي على كتب. انقل الكتب أو احذفها أولاً."

**CC-4 — Admin deletes a book with enrollments, progress, questions, certificates.**
All dependent rows cascade-delete. Certificates for that book are lost. UI must warn strongly before deletion: "سيؤدي حذف الكتاب إلى حذف كل دروسه وأسئلته وشهادات الطلاب المرتبطة به."

**CC-5 — Lesson reordering collides with the `unique (book_id, order_index)` constraint.**
Reordering must update `order_index` transactionally (e.g., temporary offset or bulk update) to avoid unique-constraint violations mid-swap.

### 6.2 External Media Failures

**CC-6 — YouTube video is deleted or made fully private.**
The player must show a graceful error ("تعذّر تحميل الفيديو") instead of crashing. Other tabs (audio/PDF/quiz) remain usable.

**CC-7 — Google Drive audio quota exceeded ("Quota Exceeded" for the day).**
The download fails; show "تعذّر تحميل الملف الصوتي حاليًا، حاول لاحقًا." If a local copy already exists, play it regardless.

**CC-8 — Google Drive PDF link is private/misconfigured.**
Show "تعذّر فتح الملف، تأكد من صلاحية الرابط." Admin-side note reminds the sheikh to set sharing to public.

**CC-9 — Audio download interrupted (connection lost mid-download).**
Partial file must be discarded; retry cleanly. Never play a corrupt partial file.

**CC-10 — No internet connection.**
Cached/downloaded content remains accessible where possible. Network-dependent screens show a friendly offline state, not a crash. Exam start is blocked with a warning (as designed in Exam Intro).

### 6.3 Exam & Quiz Edge Cases

**CC-11 — Student closes the app mid-exam.**
Since the exam is time-boxed, on return either (a) resume with remaining time if within the limit, or (b) auto-submit with answers given if time expired. RECOMMENDED: persist attempt start time; on return, compute elapsed; if expired, auto-submit. Implementer must choose and document.

**CC-12 — Exam time expires before submission.**
Auto-submit with currently selected answers; unanswered questions count as wrong (as designed in the submit confirmation copy).

**CC-13 — Student has used all attempts.**
"ابدأ الاختبار" is disabled/hidden; show "لقد استنفدت عدد المحاولات المسموحة." "عرض محاولاتي السابقة" remains available.

**CC-14 — Admin changes exam settings (time/passing %/attempts) after students have attempted.**
New settings apply to FUTURE attempts only. Existing `final_exam_attempts` records are immutable (their pass/fail already computed). Certificates already issued are not revoked.

**CC-15 — Student completes all lessons but the final exam is not published yet.**
The Final Exam card shows "الاختبار غير متاح حاليًا" instead of unlocking. It unlocks only when `is_published = true` AND all lessons complete.

**CC-16 — Final exam has zero questions.**
Students cannot start; card shows unavailable. Admin sees a warning in exam management that no questions are added.

**CC-17 — Passing threshold edge (score exactly equals passing %).**
Score `>=` passing percentage counts as a pass (inclusive).

**CC-18 — Correct answers must never reach the client pre-submission.**
Lesson quiz and final exam question fetches must exclude `correct_choice` (via a view or server-side grading). This is a security requirement, not just UX.

### 6.4 Enrollment & Progress

**CC-19 — Student tries to enroll in the same book twice.**
Blocked by `unique (user_id, book_id)`. The button already reflects enrolled state; double-tap or race must be idempotent (upsert / ignore conflict).

**CC-20 — Student opens a lesson without enrolling.**
Decision: either require enrollment before lesson access, or allow lesson viewing but only track progress post-enrollment. RECOMMENDED: require enrollment first (aligns with the explicit-enrollment business rule). Implementer must document.

**CC-21 — Progress for a lesson that was later unpublished.**
Book completion % should compute against currently-published lessons only, to avoid impossible percentages.

### 6.5 Q&A Privacy

**CC-22 — Ensuring asker anonymity to peers.**
Student-facing queries must NOT return the asker's `user_id`/name to other students. Enforce via a dedicated view or by stripping identity in the API/client layer. Admin queries return full identity. This is a privacy requirement.

**CC-23 — Student asks a question, then the lesson is deleted.**
`student_questions.lesson_id` FK cascades; the question is deleted with the lesson. Acceptable.

### 6.6 Featured Books & Banners

**CC-24 — Featured books exceed the recommended 3-5 cap.**
Admin sees a non-blocking warning. The Home screen should still render sensibly (e.g., cap the displayed count or scroll).

**CC-25 — A featured book is unpublished or deleted.**
It must drop out of the Home featured list automatically (query filters `status = 'published'`).

**CC-26 — A banner links to a book that was deleted.**
`home_banners.linked_book_id` FK is nullable; on book deletion it should be set null or the banner gracefully handles a missing target ("المحتوى غير متاح").

### 6.7 Auth & Account

**CC-27 — Duplicate email registration attempt.**
Supabase Auth + `users.email UNIQUE` reject it; show "هذا البريد مسجل بالفعل."

**CC-28 — `handle_new_user` trigger fails (e.g., missing metadata).**
`full_name` falls back to "مستخدم جديد". Registration must not be left with an auth record but no `public.users` row.

**CC-29 — The single admin account is accidentally demoted or deleted.**
Document the recovery path: re-promote via SQL (`update public.users set role='admin' ...`). No admin-management UI exists by design.

**CC-30 — Password reset requested for a non-existent email.**
Show a neutral confirmation ("إذا كان البريد مسجلًا، ستصلك رسالة") to avoid email enumeration.

---

## 7. Non-Functional Requirements

### 7.1 Performance
- Video uses progressive streaming (YouTube) — playback starts without full download.
- Audio is downloaded once and cached locally for instant replay.
- Lists (books, lessons, questions) should paginate or lazy-load for large datasets.
- Home and Path screens should render within ~2 seconds on a typical connection.

### 7.2 Security
- Row Level Security (RLS) enforced on all tables (already configured in `schema.sql`).
- The `service_role` key is NEVER used in the Flutter client; only the `anon` key.
- Correct answers (`correct_choice`) never sent to the client before grading.
- Q&A asker identity never exposed to peer students.
- API keys stored via `--dart-define` or environment config, not hardcoded.

### 7.3 Scalability & Reusability
- The codebase is a white-label template: sheikh name and primary color are the only per-deployment variables.
- Each deployment is a fresh Supabase project with the same schema.
- No cross-deployment data coupling.

### 7.4 Accessibility & Localization
- Full RTL Arabic UI.
- Light and dark themes.
- Readable Arabic typography; sufficient tap target sizes on small screens.

### 7.5 Free-Tier Hosting Constraints
- Video: YouTube (unlimited, free).
- Audio & PDF: Google Drive (mind per-file daily bandwidth quota — CC-7).
- Backend: Supabase Free tier (500 MB DB, 50k auth users) — sufficient for MVP.
- Push: FCM free tier.
- No paid storage of user-generated media (no student photo uploads by design).

### 7.6 Backend Automation Note (FCM)
Sending a push notification (e.g., "new lesson" or admin broadcast) requires backend logic to call the FCM API. This can be a Supabase Edge Function or a database trigger/webhook. The `notifications` table stores the record; actual push delivery is a backend concern to implement during development.

---

## 8. Out of Scope (Backlog)

These features are designed/considered but explicitly deferred:

1. **In-video checkpoint questions** — optional questions that pause the video at a set timestamp. Requires `checkpoint_questions` and `student_checkpoint_answers` tables when built.
2. **Guest mode** — anonymous browsing (technically easy via Supabase anonymous auth); would be a limited preview, with saving actions requiring full registration.
3. **Saved / Bookmarks screen** — lets students bookmark lessons; needs a `saved_lessons` table and a bookmark button in the lesson screen; navigation placement TBD.
4. **Web version** — same Flutter codebase built for web; requires verifying the YouTube iframe player and audio handling on web.

---

*End of PRD — Version 1.0*
