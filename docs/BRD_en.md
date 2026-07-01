# Business Requirements Document (BRD)
## "Sheikhy" App — Islamic Educational Platform

**Version:** 1.0
**Language:** English (translated from the original Arabic BRD.md)

---

## 1. Product Overview

"Sheikhy" is an **application template** for Islamic education, built for exactly **one sheikh/teacher per app instance** (not a multi-sheikh platform). Each deployment of the app is built for a specific sheikh, carrying his name and primary color as customizable variables.

The app allows the sheikh to publish his scholarly books as structured lessons (video, audio, PDF, quizzes), with an exam and certificate system, and a direct Q&A communication channel with students — relying entirely on free hosting services to minimize operating costs.

### Core Goals
- An easy-to-use platform for any sheikh who wants to publish his knowledge with negligible financial cost
- A complete educational experience for the student: organized content, progress tracking, exams, certificates
- Zero-cost hosting architecture, leveraging free services (YouTube, Google Drive, Supabase, FCM)

### Platform Scope
- Mobile app (Android / iOS) via Flutter
- Possibility of a Web version from the same codebase (Flutter Web) at a later stage, with no backend changes required

---

## 2. Users & Roles

### 2.1 Authentication System
- A single, unified authentication system for all users (student and admin), via **email and password only**
- The distinction between student and admin is made via a `Role` field stored in the database after login, not via separate Auth screens
- Based on the Role, the user is automatically routed after login to either the student interface or the admin interface (Dashboard)
- Guest login is **not supported** in the current scope — registration is mandatory for all students to track their progress

### 2.2 Role: Student
Uses the content-consumption interface: browsing books, studying lessons, taking exams, earning certificates, and asking the sheikh questions.

### 2.3 Role: Admin (Sheikh)
Uses a dashboard to manage all app content: scientific sections, books, lessons, questions, exams, notifications, and replying to student questions.

---

## 3. Authentication Requirements

### Screens
| # | Screen | Description |
|---|--------|-------------|
| 1 | Splash Screen | Sheikh's logo + app name + "تحت إشراف اللجنة العلمية" text + loading indicator |
| 2 | Login | Email + password + "forgot password" link |
| 3 | Sign Up | Full name + email + password + confirm password + mandatory terms-acceptance checkbox |
| 4 | Forgot Password | Email field only |
| 5 | Reset Link Sent Confirmation | Visual confirmation + "open email app" button + "resend" with a 45-second countdown cooldown |

### Business Rules
- **Registration and login happen via email and password only** (no Google or any other third-party sign-in)
- Accepting the "Terms & Conditions and Privacy Policy" is mandatory during registration
- The password reset link is time-limited
- The "resend" button is rate-limited (cooldown) to prevent repeated sending
- A single authentication system serves both student and admin (see 2.1)
- **Guest login (no account) is not supported in the current scope** — see Section 7 (Future Enhancements) for details on adding it later as a limited preview

---

## 4. Student-Facing Requirements

### 4.1 Core Screens & Navigation

**Unified bottom navigation bar (4 fixed items across all screens):**
1. Home (الرئيسية)
2. Path (المسار)
3. My Achievements (إنجازاتي)
4. My Profile (حسابي)

| # | Screen | Description |
|---|--------|-------------|
| 1 | Home | Greeting with student's name + notifications icon + featured-courses banner (Carousel, **fully managed from the "Banner Management" screen in Admin**) + "Top Books" list (**featured books enabled by the admin, in his manual order**) with a progress bar. **Intended for quick promotional display only, not the main hierarchical navigation point** |
| 2 | Path | The primary entry point for structured content navigation: shows currently in-progress lessons (Continue Learning) + a prominent card for the last-followed lesson + access to Scientific Sections |
| 3 | Scientific Sections | A 2×2 grid of book categories (creed, jurisprudence, tafsir, biography, etc.), each card with an icon + name + book count. **Accessed via the "Path" screen, not directly from Home** |
| 4 | Books of a Section | Displays the books of a given scientific section, with a search bar, book cards with progress bars |
| 5 | My Achievements | 3 stat cards (completed lessons, study hours, completed books) + annual activity heatmap (4 shading levels) + certificates list (book name, date, final percentage, download button) |
| 6 | My Profile | **Default avatar (initials-based)** — no personal photo upload — + name + email + edit button + 3 stats + list (My Certificates, Change Password, Dark Mode, About the App, Log Out) |
| 7 | Edit Profile | Editable name + email (**read-only, not editable**) + separate section for changing password (requires current password for verification). **No profile photo upload/change** |
| 8 | Notifications | A uniformly-styled list for all notification types (live stream, new lesson, study reminder, achievement), with no special visual distinction per type; each card is fully clickable |
| 9 | Saved (Bookmarks) — *Backlog* | A screen for saving specific lessons the student wants to easily revisit later, via a "Save" (bookmark) button in the lesson screen |

### Business Rules
- Home = quick/promotional display. Path = structured navigation (Scientific Sections → Books of Section → Book Details)
- The annual activity heatmap records the student's daily activity level
- Certificates display: book name, issue date, final percentage, PDF download button
- Dark mode is toggled from "My Profile" via a switch
- Email cannot be changed from the app interface (tied to account identity in the auth system)
- **No profile photo upload feature is available for students** (to reduce storage cost); a default avatar generated from the first letter of the student's name is shown instead
- The live-stream notification has the same shape and size as other notifications (no special visual treatment); its link is part of the notification's own data (fully clickable)

### 4.2 Book & Lesson Details

| # | Screen | Description |
|---|--------|-------------|
| 9 | Book Details | Cover image + name + description + overall progress bar + numbered lesson list (completed/locked) + "Final Exam" card at the end of the list + **"Enroll in Book" button (first visit, with a Confirmation Dialog) that becomes "Continue Studying" after confirmation** |
| 10 | Lesson Screen | Video player + lesson name + description + **4-tab bar: Video / Audio / PDF / Quiz** + a quick entry to ask the sheikh a question + "Next Lesson" button |
| 11 | Lesson Quiz | A short quiz specific to each lesson (Multiple Choice + Timer + question numbering), **separate from the book's comprehensive Final Exam** |
| 12 | Ask Your Question (Q&A - Student) | A pop-up (Bottom Sheet) to submit a question linked to a specific lesson |
| 13 | Book Questions (Q&A - Display) | **A standalone screen at the book level** (accessed from "Book Details"), aggregating all questions from all of the book's lessons into a single list, with the associated lesson name shown as a sub-detail for each question, and displaying the sheikh's replies |

### Business Rules
- The lesson's 4 tabs are: Video, Audio, PDF, Quiz (not "Questions" as initially assumed)
- There are two levels of assessments: the **Lesson Quiz** (short, specific to each lesson) and the **Final Exam** (appears after completing all of the book's lessons)
- The Final Exam is locked until the student completes all of the book's lessons
- **Enrollment:** On a student's first visit to a book, an "Enroll in Book" button is shown instead of "Continue Studying"; tapping it opens a Confirmation Dialog to confirm intent; after confirmation, an actual `enrollment` record is created and used to accurately calculate "enrolled students" statistics in the Admin dashboard
- **Q&A System:**
  - **Question input** happens within the context of a specific lesson (the student asks while inside the lesson)
  - **Question display** happens in a unified screen at the book level (not within each individual lesson)
  - The sheikh's reply is visible **to all students studying that lesson** (public and useful, not exclusive to the asker)
  - **The asker's identity is always clearly visible to the admin in his dashboard, and always anonymized in front of other students**

### 4.3 Final Exam & Certificate

| # | Screen | Description |
|---|--------|-------------|
| 13 | Final Exam Intro | Question count + time available + required passing percentage + "Start Exam" button + "View My Previous Attempts" link |
| 14 | Taking the Exam | Top bar (Timer + question number) + progress bar + Multiple Choice question + **Question Navigator** grid for direct navigation, with answered questions shown in a different color |
| 15 | Submit Confirmation | A warning Modal showing the count of unanswered questions + option to "Review Questions" or "Submit Exam" |
| 16 | Result & Certificate | Circular success percentage + correct-answer breakdown + certificate preview + "Download Certificate" button |

### Business Rules
- **The sheikh manually enters the Final Exam questions himself**, not randomly drawn from a large question bank
- **Unified Question Bank (optional):** The sheikh can choose questions from the question bank (any question he previously added in lesson quizzes) to build the Final Exam, while also being able to add new questions by writing them — choosing from the bank is optional, not mandatory
- The number of Final Exam attempts is **customizable per book by the admin** (not unlimited by default; the suggested default value is 2-3 attempts)
- A record of previous attempts (date + result) is available to the student before starting a new attempt
- Customizable Final Exam settings per book: time available, required passing percentage, allowed number of attempts

---

## 5. Admin-Facing Requirements

### 5.1 Main Dashboard

An independent bottom navigation bar for the admin (2 items only): **Dashboard**, **Settings**

| # | Screen | Description |
|---|--------|-------------|
| 1 | Dashboard | 4 stat cards (lesson count, book count, certificates granted, student count) + 3 quick-action buttons (Add Section, Add Book, Add Notification) + "My Books" list |
| 2 | Add Scientific Section | Section name + icon selection from a fixed set (8 icons: lamp, book, scale, heart, historical clock, mosque, graduation cap, star) + optional description + current-sections list |
| 3 | Add New Book | Cover image + name + description + classification (scientific section selector) + **"Show this book on the Home page" switch (featured book)** + "Save and Continue to Add Lessons" button |
| 4 | Edit Book | Same fields as adding, pre-loaded with existing data |
| 5 | Add New Notification | Notification type (general / live stream / new lesson / reminder) + title + text (with character counter) + optional additional link (for a live-stream link or a book/lesson link) + immediate-send/schedule switch + live preview |
| 6 | Banner Management (Home Banner) | A screen to add/edit/delete Home page banners (Carousel); each banner includes: image/background + title + short description + link (to a specific book or an external link) + reorderable display order (drag) |

### Business Rules
- **A book's status has two independent axes:**
  - (Published / Draft): controls the book's visibility to students
  - (Completed / In Review): an internal indicator for the admin only, does not affect the book's visibility to students
- The icons available for scientific sections are limited to a fixed set the admin chooses from (not a custom image upload)
- The "additional link" field in a notification is generic for all types, used according to the notification type's context
- **Featured Books on the Home Page:**
  - A book's appearance in the "Top Books" list on Home is enabled via a dedicated switch in the Add/Edit Book screen
  - **The display order of featured books is determined entirely manually by the admin** (drag-and-drop or an order-number field), not automatically
  - There is a suggested maximum number of featured books displayed on Home (3-5 books) to prevent UI clutter, with a warning to the admin when the limit is exceeded
- **Home banners** are fully managed from the "Banner Management" screen, and support multiple banners in a single Carousel with a customizable order

### 5.2 Book-Specific Dashboard (Book Dashboard)

When the admin enters a specific book from the "My Books" list, he enters a dashboard dedicated to that book, with a tab bar: **Lessons | Statistics | Questions | Settings**

| Tab | Contents |
|-----|----------|
| Lessons (a combined Dashboard-style screen) | "Add New Lesson" button + lesson list (number, name, available-content icons, published/draft status, drag-to-reorder) + **statistics summary** (completion percentage, total students, average exam score with a star rating, an enrollment progress chart) + **latest questions** (the 2 most recent student questions) + a separate "Final Exam" card with a dashed border |
| Questions | A full standalone screen: two tabs "Awaiting Reply" (with a counter) and "Replied To", each question card showing the student's photo + name + related book/lesson + question text + an inline reply field |
| Settings | Book-specific settings (details to be defined later) |

### Business Rules
- The "Lessons" screen in the Book Dashboard is a single scrollable screen that combines the lesson list + statistics + latest questions, and is not strictly divided into fully isolated tabs
- The student's identity (name + photo) is shown in full to the admin in the Questions screen, reaffirming the Q&A privacy rule

### 5.3 Adding & Editing Lessons

The "Add New Lesson" screen contains the lesson name + a 4-tab bar for content entry: **Quiz | PDF | Audio | Video**

| Tab | Fields |
|-----|--------|
| Video | "Video link" field (YouTube) + automatic preview + "Publish lesson immediately" switch |
| Audio | "Audio file link" field (supports YouTube Audio or Telegram) + audio-player preview + "This lesson is audio-only, no video" switch |
| PDF | "PDF file link" field (Google Drive, with a notice that sharing settings must be set to "public") + file preview (name + icon + open + delete) |
| Quiz | Question counter + question list (text + 4 choices + marking the correct answer) + edit/delete |

### Business Rules
- **Saving is unified across all tabs:** the lesson is a single record in the database; the "Save Lesson" button (persistently shown across every tab) saves the data of all four tabs at once, regardless of which tab was active when pressed
- Content hosting sources are entirely free: video (YouTube Unlisted), audio (YouTube Audio or Telegram), PDF (Google Drive link)
- PDF files: external link only in the current scope (no direct upload to Supabase Storage in the MVP, to minimize resource consumption)

### 5.4 Final Exam Questions (Management)

A separate screen per book: 3 settings fields (time available in minutes, required passing percentage %, allowed number of attempts) + "Add New Question" button + question list (reorderable by drag) + "Preview Exam as the Student Sees It" button + "Save and Publish Exam" button

---

## 6. Technical Stack

| Component | Adopted Solution | Rationale |
|-----------|-------------------|-----------|
| Frontend | Flutter (Mobile + expandable to Web later with the same code) | Single development cost, cross-platform |
| Backend | **Supabase** (PostgreSQL) | Free for the current scope, REST API + Realtime |
| Video Hosting | YouTube (Unlisted) | No bandwidth cost, progressive streaming |
| **Audio Hosting** | **Google Drive, using a "download then play locally" approach** | Uses the same source as PDF, no need for a complex streaming layer |
| PDF Hosting | Google Drive (public share link) | No consumption of Supabase storage space |
| Notifications (Push) | Firebase Cloud Messaging (FCM) | Free, entirely separate from the Backend (Supabase) decision |
| UI Design | Google Stitch AI (Arabic RTL Prompts) | Rapid prototyping before implementation |

> **Important note:** The Backend is Supabase exclusively. Any mention of Firebase refers solely to the notifications service (FCM), and does not represent any change to the database or core infrastructure.

### Audio Playback Mechanism from Google Drive (Technical Detail)

1. The admin uploads the audio file to Google Drive, sets its sharing settings to "public," then pastes the share link into the "Audio File Link" field in the Add Lesson screen
2. The app automatically converts the link into the direct-download format: `https://drive.google.com/uc?export=download&id=FILE_ID`
3. When a student enters the "Audio" tab in the Lesson screen, a "Download" button appears instead of direct playback (streaming)
4. Upon tapping "Download": the file is downloaded in full to the device's local storage (requires Storage Permission), then played with a local audio player
5. **The app must first check whether the file has already been downloaded on the student's device** before re-downloading, to save time and data usage
6. **A known and accepted constraint:** Google Drive's daily bandwidth quota per file still applies (less severe than direct streaming, but not eliminated); under heavy load on a given lesson within a single day, some students may temporarily see a "quota exceeded" message

---

## 7. Future Enhancements (Backlog)

The following features are **already designed** (Stitch designs ready), but are **deferred to a later phase (Next Phase)** and will not be built within the current MVP scope:

### 7.1 In-Video Checkpoint Questions
- An optional question (with a "skip" button) that appears at a specific timestamp mid-video, automatically pausing playback
- The admin sets the timestamp + question text + choices from the Video tab in the Add Lesson screen
- Student interaction (answered/skipped) is recorded for future statistics
- The question is not shown again if the student rewinds to a point previously seen in the same session

### 7.2 Guest Login (Guest Mode)
- Technically simple to implement via Supabase Anonymous Sign-in
- Suggested to be a "limited preview" only (e.g., the first lesson of each book, without progress tracking), while any feature that saves data (progress, certificate, question) requires full registration with email

### 7.3 Saved/Bookmarks Screen
- A new screen for students to save specific lessons to easily return to later
- Requires a "Save" (bookmark icon) button inside the Lesson screen
- Requires a `saved_lessons` table linking the student to saved lessons (Many-to-Many relationship)
- Open decision to be resolved at implementation time: a standalone screen in the navigation bar (making it 5 items), or a sub-section within "My Profile"

---

## 8. Critical Business Rules Summary

1. The app is dedicated to a single sheikh per instance (not a multi-sheikh platform)
2. A single, unified authentication system for student and admin via email and password only (no Google), distinguished via `Role`
3. Registration is mandatory for all students (no guest mode in the current scope)
4. Home is for quick display; Path is for structured content navigation
5. Each lesson has its own short quiz, separate from the book's Final Exam
6. The Final Exam is locked until all of the book's lessons are completed
7. Final Exam questions are written manually by the sheikh, with an optional ability to select from the lesson question bank
8. The number of Final Exam attempts is customizable per book
9. Actual enrollment in a book (Enrollment) happens via a dedicated button with a Confirmation Dialog, not automatically upon entry
10. The sheikh's replies to student questions are visible to all students of that lesson (not just the asker); and all of a book's questions are displayed in a unified, book-level screen
11. Asker identity in Q&A: always visible to the admin, always anonymized in front of other students
12. A book's status has two independent axes: (Published/Draft) and (Completed/In Review)
13. Saving a lesson's data (video/audio/PDF/quiz) happens in a single, unified operation
14. Video is hosted on YouTube; audio and PDF are hosted on Google Drive (audio via local download-then-play)
15. Email cannot be edited from the student interface after registration
16. No student profile photo upload exists; a default avatar image is used, generated from the first letter of the name

---

*End of Document — Version 1.0*
