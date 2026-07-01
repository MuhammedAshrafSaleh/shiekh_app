# Sheikhy (شيخي) — Flutter App Build Plan

Single-sheikh (white-label, **not** multi-tenant) Islamic education app. Flutter + Supabase, RTL Arabic,
light/dark, dark-green primary + gold accent. Built for zero hosting cost (YouTube video, Google-Drive
audio/PDF, Supabase + FCM free tiers). Backend (`docs/schema.sql` + corrected `docs/Supabase_Setup_Guide.md`)
is **finalized and authoritative — not to be redesigned**. UI matches `docs/screens/`.

> **Workflow:** build **one phase at a time, stop for review** before the next. Each phase below is a
> checklist of tasks.

---

## Confirmed Decisions
- **State management:** Bloc/Cubit (`flutter_bloc`) — Cubit for most screens, full **Bloc for the exam**.
- **Backend gaps:** one **additive companion migration** (student-safe views + `submit_final_exam` RPC).
- **Auth:** email confirmation **ON** (code handles both ON/OFF); `on_auth_user_created` trigger **already exists → verify, don't duplicate**; client does **not** insert the profile row.
- **Media images:** default to one public `media` Storage bucket (confirm at Phase 6) — else paste URL.

---

## ⚠️ Conflicts & Ambiguities (resolved)
| # | Issue | Resolution |
|---|---|---|
| A | `certificates` has **no INSERT policy** | Issue certs inside `submit_final_exam` SECURITY DEFINER RPC |
| B | `correct_choice` client-readable (CC-18) | Student views omit it; base SELECT tightened to `is_admin()`; grade server-side |
| C | Q&A `user_id` exposed (CC-22) | `student_questions_public` view (no user_id); base SELECT → `is_admin()` |
| D | PRD's `handle_new_user` vs schema | Trigger `on_auth_user_created` **exists in live DB** → use it; don't duplicate |
| E | Old setup guide = wrong app | Corrected Sheikhy guide now authoritative |
| F | Email confirm ON vs guide "OFF" | Code handles both; target ON (flip Supabase toggle) |
| G | No Storage bucket, but upload UI | Add one public `media` bucket (admin-write/public-read) or paste URL |
| H | `achievement` notif has no admin path | System-generated on certificate issuance |
| I | Mockups show Google sign-in + photos | Spec wins: email/password only, **initials avatars** |
| J | Mockup brand "Sakinah" | Per-deployment variable; nothing hardcoded |
| K | Docs say 16 tables | Actually **15**; build against those |
| L | Lesson "complete" undefined | ~90% of primary medium **or** tap "الدرس التالي", **and** quiz answered (if any) |
| M | Study-hours/heatmap undefined | Heatmap = daily activity events (progress + attempts) in 4 buckets; hours ≈ completed × avg mins |
| N | FCM/scheduled sends unspecified | v1 = full in-app notifications; optional topic-based FCM; scheduled = follow-up |

**"Implementer must document" corner cases:**
- **CC-2** unpublish enrolled book → **hide + "غير متاح حاليًا"**, enrollment row persists.
- **CC-11** app closed mid-exam → **persist start; resume remaining time or auto-submit if expired**.
- **CC-20** lesson without enrolling → **require enrollment first** (tap opens enroll dialog).

---

## Tech Stack
`supabase_flutter` · `flutter_bloc`/`bloc`/`equatable` · `go_router` · `youtube_player_iframe` ·
`just_audio`+`audio_session`+`dio`+`path_provider` (audio download-then-play) · `pdfx` (PDF) ·
`pdf`+`printing` (client-side certificate) · `fl_chart` · `flutter_heatmap_calendar` ·
`cached_network_image`+`image_picker` · `connectivity_plus` · `shared_preferences` ·
`flutter_localizations`+`intl` · `url_launcher` · `carousel_slider` · `permission_handler` ·
`google_fonts` (Cairo/Tajawal) · optional `firebase_core`+`firebase_messaging` · config via `--dart-define`.

## Project Structure (feature-first + Bloc)
```
lib/
  main.dart
  app/{app.dart, router.dart, bloc_providers.dart}
  core/
    config/{app_config.dart, brand.dart}   theme/app_theme.dart   supabase/supabase.dart
    l10n/   utils/{drive_url, relative_time, result}   widgets/   errors/
  models/                                   # DTOs w/ fromJson for the 15 tables/views
  features/
    auth/ home/ path/ sections/ books/ lesson/ quiz/ exam/ certificates/
    achievements/ qa/ profile/ notifications/
    admin/{dashboard,sections,books,lessons,exam,banners,qa,stats}/
      # per feature: data/<x>_repository.dart · cubit|bloc/ · view/ · widgets/
```

---

## State Management Approach
- **Global:** `AuthCubit` (session + role, drives routing), `ThemeCubit`, `ConnectivityCubit`. **Per-feature Cubits** for screens; **full `ExamBloc`** for the exam (timer / answers map / navigator status / resume).
- **Standard state shape** across every Cubit/Bloc: `Initial → Loading → Loaded(data)` (+ `Empty`) `→ Error(message)` — Equatable states, UI switches on the current state.
- **Realtime vs refetch:**
  - **Realtime** Supabase channel subscriptions on exactly two surfaces — **student Notifications list** and **admin Q&A inbox** — where live updates matter.
  - **Everything else = plain refetch-after-mutation + pull-to-refresh** (request/response). No global realtime.
- **Key write patterns:**
  - `lesson_progress`: **upsert on `(user_id, lesson_id)`** (onConflict) — one row per student/lesson; sets `completed`, `last_position_seconds`, `completed_at`.
  - `enrollments`: **insert with conflict-ignore** on `(user_id, book_id)` — idempotent (CC-19).
  - `notification_reads`: **bulk insert** one row per unread notification for "تحديد الكل كمقروء".
  - Final exam: **single `submit_final_exam` RPC call** (no client-side attempt/cert writes); Q&A: student `insert`, admin `update` (answer + status).
- **Repositories** wrap all Supabase calls; Cubits/Blocs depend only on repositories.

---

# PHASES & TASKS

## Phase 0 — Project Scaffold & Infrastructure
- [x] 0.1 `flutter create` (org `io.sheikhy.app`), set up folder structure above.
- [x] 0.2 Add all dependencies; `flutter pub get`; `flutter analyze` clean.
- [x] 0.3 `AppConfig` reading `--dart-define` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SHEIKH_NAME`, `PRIMARY_COLOR`); commit `dart_define.example.json`.
- [x] 0.4 `Supabase.initialize` in `main.dart`; connectivity smoke test (`from('books').select().limit(1)`).
- [x] 0.5 Theme (`ColorScheme.fromSeed` light + dark, gold accent, Cairo font, cards/badges/progress styles); `ThemeCubit` + persistence.
- [x] 0.6 RTL + Arabic locale (`Locale('ar')`, delegates); global RTL verified.
- [x] 0.7 `go_router` skeleton + `AuthCubit`-driven role redirect (placeholders).
- [x] 0.8 Shared widgets: PrimaryButton, AppCard, ProgressBar, EmptyState, ErrorState, InitialsAvatar, SectionIcon registry (8 icons), StatusBadge, McqOptionCard, OfflineBanner.
- [x] 0.9 **Companion migration** `supabase/migrations/0001_app_support.sql` (you review + run): 3 student views; tighten `quiz_select_all`/`final_exam_q_select_all`/`questions_select_all` → `is_admin()`; `submit_final_exam(p_book_id,p_answers,p_started_at)` RPC (guards, attempt limit CC-13, server grade CC-18, insert attempt + cert ON CONFLICT DO NOTHING with **grade_label banding (≥90 ممتاز / ≥80 جيد جداً / else جيد)**, achievement notif); `grade_lesson_quiz` RPC; **verify `on_auth_user_created` exists — do not recreate**.
- 🛑 **Review gate.**

## Phase 1 — Auth & Role Routing (`docs/screens/#1 Auth`)
- [ ] 1.1 `AuthRepository` + `AuthCubit` (session, role, signIn/signUp/signOut/reset).
- [ ] 1.2 Splash (brand logo/name, "تحت إشراف اللجنة العلمية", loader → route by session/role).
- [ ] 1.3 Login (email/password + show-hide, forgot link, inline Arabic errors — CC-27).
- [ ] 1.4 Sign Up (name/email/pw/confirm + **mandatory terms checkbox**; handle confirm-ON/OFF — F).
- [ ] 1.5 Forgot Password + Reset-Sent (open-email button, **45s resend cooldown**, neutral msg CC-30).
- [ ] 1.6 Deep link `io.sheikhy.app://reset-callback`; role-based redirect (student→Home, admin→Admin).
- 🛑 **Review gate.**

## Phase 2 — Student Shell & Discovery (`#2 Student Home`)
- [ ] 2.1 Bottom nav shell (الرئيسية/المسار/إنجازاتي/حسابي), active = green pill.
- [ ] 2.2 Home: banner carousel (`home_banners` active, ordered) + featured books (`is_featured && published`) with progress; banner tap → book/external; empty/default state.
- [ ] 2.3 Path: "جارية الآن"/"لم تبدأ بعد" tabs, continue-card deep-link, in-progress list, empty state.
- [ ] 2.4 Scientific Sections grid (2-col, published book counts, fixed icons, empty state).
- [ ] 2.5 Books-of-Section (published only, search, progress bars, 100%=gold).
- 🛑 **Review gate.**

## Phase 3 — Book, Lesson, Q&A (`#3 Video Section`)
- [ ] 3.1 Book Details: cover/desc/overall progress, numbered lessons (complete/locked), locked Final-Exam card.
- [ ] 3.2 Enrollment: first visit "تسجيل في الكتاب" → confirm dialog → `enrollments` insert (idempotent CC-19); then "استمرار المذاكرة"; **gate lesson access on enrollment (CC-20)**.
- [ ] 3.3 Lesson shell: 4 tabs فيديو/صوت/PDF/اختبار, default = first available; "اسأل سؤالك" entry; "الدرس التالي".
- [ ] 3.4 Video tab: `youtube_player_iframe`; save `last_position_seconds`; resume; error CC-6.
- [ ] 3.5 Audio tab: Drive→`uc?export=download` (`drive_url`), `dio` download w/ progress + cancel, local cache + reuse check, `just_audio` playback; CC-7/CC-9/CC-10.
- [ ] 3.6 PDF tab: `pdfx` from Drive URL; error CC-8.
- [ ] 3.7 Lesson Quiz: fetch via `lesson_quiz_questions_student` view; `grade_lesson_quiz` feedback; MCQ UI + timer.
- [ ] 3.8 Progress/completion (rule L): upsert `lesson_progress`; recompute book % vs published lessons (CC-1/CC-21).
- [ ] 3.9 Q&A bottom sheet (privacy notice, char counter) → insert `student_questions` (pending, lesson+book).
- [ ] 3.10 Book-level Q&A screen via `student_questions_public` (peer-anonymous CC-22; pending badge/answers).
- 🛑 **Review gate.**

## Phase 4 — Final Exam, Certificates, Achievements (`#3`, `#2`)
- [ ] 4.1 `ExamBloc` (timer stream, answers map, navigator status, resume/auto-submit CC-11/CC-12).
- [ ] 4.2 Exam Intro (count/time/pass %, attempts + lock CC-13/CC-15/CC-16, past-attempts link).
- [ ] 4.3 Exam In-Progress (red-timer, navigator grid, MCQ via `final_exam_questions_student` view, prev/next).
- [ ] 4.4 Submit-confirm modal (unanswered warning) → `submit_final_exam` RPC (CC-17 inclusive).
- [ ] 4.5 Result screen (score ring, correct count, cert preview, download/back).
- [ ] 4.6 Certificate client-side PDF (`pdf`+`printing`) + share/save; list from `certificates`.
- [ ] 4.7 Achievements: 3 stat cards, activity heatmap (M), certificates list, empty state.
- 🛑 **Review gate.**

## Phase 5 — Profile & Notifications (`#2`)
- [ ] 5.1 Profile (initials avatar, 3 stats, list: شهاداتي/تغيير كلمة المرور/الوضع الليلي toggle/عن التطبيق/تسجيل الخروج).
- [ ] 5.2 Edit Profile (name editable, email read-only, change-password w/ current-password verify).
- [ ] 5.3 Notifications: uniform cards, unread dots + light bg, deep-link on tap, mark-all-read (bulk `notification_reads`), Realtime live-update.
- [ ] 5.4 *(Optional)* Topic-based FCM (`students` topic) + Edge Function on insert — N.
- 🛑 **Review gate.**

## Phase 6 — Admin Core (`#4 Admin Home`)
- [ ] 6.1 Admin 2-tab shell (لوحة التحكم/الإعدادات), gold active pill.
- [ ] 6.2 Dashboard: live stat cards, 3 quick actions, "كتبي" list w/ dual-axis badges, edit/delete (CC-4 warning).
- [ ] 6.3 Section mgmt: name + fixed 8-icon picker + desc; list w/ counts; delete-restrict error (CC-3).
- [ ] 6.4 Book mgmt: cover (bucket G), title/desc/section dropdown, **featured toggle + order** (3–5 cap warning CC-24), dual status axes (status/review_status).
- [ ] 6.5 Banner mgmt: add/edit/delete, order, `is_active`, book/external link (CC-26 nullable target).
- 🛑 **Review gate.**

## Phase 7 — Admin Authoring (`#5 Add Lesson`, `#6 Book Stats`)
- [ ] 7.1 Lesson mgmt: 4 tabs (video/audio/PDF/quiz) with **one sticky "حفظ الدرس" → unified single-record save**.
- [ ] 7.2 Lesson-quiz authoring (text, 4 choices, mark correct, edit/delete).
- [ ] 7.3 Lesson reorder: transactional `order_index` update (CC-5); publish toggle.
- [ ] 7.4 Final-exam mgmt: settings (time/pass %/attempts), questions + **optional bank import** (`source_quiz_question_id`), preview, publish (CC-14/CC-16).
- [ ] 7.5 Per-book dashboard: combined Lessons+stats+recent-questions tab; Statistics (completion, students, avg score+stars, enrollment chart via `fl_chart`).
- [ ] 7.6 Admin Q&A answering (full identity, pending/answered tabs, inline reply → answered + notify asker).
- [ ] 7.7 Admin Notifications create (4 authorable types, char counter, link, immediate/schedule, preview).
- 🛑 **Review gate.**

## Phase 8 — Hardening & White-label
- [ ] 8.1 Sweep all 30 corner cases (table below); offline/error/empty states everywhere.
- [ ] 8.2 RTL + light/dark QA against each `docs/screens/` mockup.
- [ ] 8.3 Performance (lazy/paginated lists, ~2s Home/Path).
- [ ] 8.4 Security spot-check (student cannot read peer identity or any `correct_choice`).
- [ ] 8.5 White-label README (re-deploy steps: new Supabase → run schema + migration → `--dart-define` → swap brand assets; CC-29 admin recovery SQL).
- 🛑 **Review gate.**

---

## Corner-Case Handling (all 30)
1 cascade+recompute · **2 hide+"غير متاح", keep enrollment** · 3 restrict error · 4 strong delete warning ·
5 transactional reorder · 6 video error/other tabs ok · 7 quota msg/play local · 8 PDF error+admin note ·
9 discard partial+retry · 10 offline states/cached ok/exam blocked · **11 resume-or-auto-submit** ·
12 timer auto-submit · 13 RPC enforces attempts · 14 future-only settings, past immutable ·
15 "غير متاح" until published · 16 zero-Q locked+admin warning · 17 `>=` pass · 18 views+server grade ·
19 idempotent enroll · **20 require enrollment** · 21 % vs published only · 22 anonymized view ·
23 question cascades · 24 non-blocking cap warning · 25 featured auto-drops · 26 nullable banner target ·
27 dup-email msg · 28 handled by existing trigger · 29 documented SQL recovery · 30 neutral reset msg.

## Verification
- **Backend:** run migration; confirm 3 views + 3 tightened policies + single `on_auth_user_created`; call `submit_final_exam` → attempt+cert+notif; student `select` on exam questions returns no `correct_choice`.
- **Per phase:** seed admin + student; walk happy path + 2–3 corner cases on device (`--dart-define`).
- **Auth:** both confirm ON/OFF; reset deep link.
- **RTL/theme:** every screen light+dark vs mockup. Widget tests for grading/progress/enroll-gate/timer.

## Out of Scope (backlog — do NOT build)
In-video checkpoint questions · Guest mode · Saved/Bookmarks · Web build. (Scheduled push + real FCM optional/deferred.)
