# Sheikhy — Incremental Testing Plan

Companion to `plan.md`. Testing is **incremental**: it happens at every phase's review
gate (🛑), not as one giant pass at the end. Each phase verifies **its own** corner
cases (by CC number) plus a smoke test of what was just built. **Phase 8 remains the
full sweep** — all 30 corner cases end-to-end + RTL/theme QA against every mockup.

Four levels, applied every phase:

1. **Unit tests** (repository layer) — success path + every `Failure` path, Supabase
   mocked (`mocktail`). Security-sensitive methods additionally assert they query the
   **`_student` views** (not base tables) and **`student_questions_public`** (not raw
   `student_questions`).
2. **Widget tests** — stateful/complex UI only (exam timer + resume/auto-submit, MCQ
   selection + navigator grid, progress-bar %, enrollment button `تسجيل → استمرار`,
   unified 4-tab lesson save).
3. **Manual per-phase verification** — real device + live Supabase, one **admin
   (sheikh)** + one **student** seed account; walk the phase happy path + its 2–3 most
   important corner cases. Documented as a 3–6 item checklist per phase.
4. **Security spot-checks** — as an authenticated student, hit the raw API (not the UI)
   and confirm `correct_choice` / peer `user_id` are **unreachable at the RLS level**,
   not merely hidden by a view or the client. Run these the moment the relevant phase
   (and the companion migration) lands — never deferred to Phase 8.

**Commands**

```bash
flutter test                          # all unit + widget tests
flutter test test/path/to/x_test.dart # single file
flutter analyze
```

**Test layout mirrors `lib/`:** `test/features/<feature>/<x>_repository_test.dart`,
`test/features/<feature>/<x>_cubit_test.dart`, `test/features/<feature>/view/…_test.dart`.

---

## PART 1 — Retroactive coverage for Phases 0–1 (DONE)

### Automated tests added
| File | Covers |
|---|---|
| `test/features/auth/auth_repository_test.dart` | `AuthRepository` — 12 tests: `signIn`/`signUp`/`resetPassword`/`signOut` success + each mapped Arabic `Failure` path (invalid creds, unconfirmed email, duplicate email CC-27, weak password, rate-limit CC-30, unexpected→`ServerFailure`); `getUserRole` null-user path. |
| `test/widget_test.dart` | Splash, Login, Sign Up, Forgot Password, Reset-Sent — render required Arabic copy + empty-field validation. Harness rewritten to use a **mocked `AuthRepository`** (was previously non-compiling: `implements dynamic`, const-ctor on non-const super, and a wrong `package:sheikh_app` import — all fixed; package is `sheikhy_app`). |

Status: **19/19 passing, `flutter analyze` clean.** Reproduce with `flutter test`.

> Not unit-tested yet: `AuthRepository.getUserRole()` success path (the
> `.from('users').select().eq().single()` chain) — deferred; it is exercised by the
> manual role-routing check below and will get a fixture-backed test when the first
> data-table repository (Phase 2) establishes the query-mock pattern.

### 🔒 Companion-migration security checklist (do this FIRST — foundation for all later phases)
Run in the Supabase SQL editor / a client authenticated **as a student** (anon key +
student JWT). This is the single most important thing to verify before Phase 2.

- [ ] **Migration ran cleanly:** `0001_app_support.sql` executed; the `on_auth_user_created`
      check raised `OK: … trigger exists` (NOT the `MISSING TRIGGER` warning).
- [ ] **Three views exist:** `lesson_quiz_questions_student`, `final_exam_questions_student`,
      `student_questions_public` — and each **omits** `correct_choice` / `user_id`
      respectively (`select * from … limit 1` and inspect columns).
- [ ] **Base tables locked (RLS, not just view convenience):** as a student,
      `select correct_choice from lesson_quiz_questions limit 1` and
      `select correct_choice from final_exam_questions limit 1` must both return
      **0 rows / permission denied** — the tightened `*_select_admin` policies (`is_admin()`).
- [ ] **Peer identity locked:** as student A, `select user_id from student_questions limit 1`
      returns **0 rows** (base table admin-only); the public view exposes no `user_id`.
- [ ] **`submit_final_exam` is authoritative:** `execute` granted to `authenticated`, `public`
      revoked; a direct call with a bogus `p_book_id` raises `NOT_ENROLLED`, and grading /
      attempt-count / certificate issuance all happen server-side (no `correct_choice`
      crosses the wire).
- [ ] **`grade_lesson_quiz`:** `execute` granted to `authenticated` only; returns
      `{correct,total,percentage}` without leaking correct answers.

### Manual device checklist — Phases 0–1 (walk now, before building on top)
Seed one **admin** and one **student** account first.

- [ ] **Config/white-label (0.3/0.5):** app launches via
      `flutter run --dart-define-from-file=dart_define.json`; sheikh name + primary color
      come from config (no hardcoded brand); toggling theme persists across restart (`app_theme`).
- [ ] **RTL + Arabic (0.6):** every auth screen is right-aligned, mirrored, Cairo font,
      no clipped/overflowing text — light **and** dark.
- [ ] **Role routing (0.7 / 1.6):** no session → `/login`; student login → `/home`;
      admin login → `/admin`. Kill & relaunch while logged in → lands on the right shell
      (session restored).
- [ ] **Login (1.3):** wrong password shows `البريد الإلكتروني أو كلمة المرور غير صحيحة`;
      show/hide password toggle works; inline empty-field errors (CC-27).
- [ ] **Sign Up (1.4):** terms checkbox is mandatory; duplicate email →
      `هذا البريد الإلكتروني مسجّل مسبقاً`; confirm-ON path shows the "check your email"
      state, confirm-OFF path signs straight in (handles both — F).
- [ ] **Forgot/Reset (1.5):** 45s resend cooldown counts down and disables the button;
      neutral message regardless of whether the email exists (CC-30); deep link
      `io.sheikhy.app://reset-callback` opens the app.

### Corner cases covered by Phases 0–1
- **CC-27** duplicate-email message — unit-tested ✅ + manual.
- **CC-28** profile row created by existing trigger (client never inserts) — verify via
      migration checklist (trigger present) + manual sign-up creates a `users` row ✅.
- **CC-30** neutral password-reset message — unit-tested (rate-limit mapping) ✅ + manual.
- **CC-29** admin-recovery SQL — documented at Phase 8 (white-label README); N/A to build now.

---

## PART 2 — Per-phase testing (Phase 2 onward)

At **each** 🛑 review gate I hand you: (a) the unit/widget tests written that phase,
(b) a 3–6 item device checklist, (c) the CC numbers now covered. Targets below —
refined to match whatever actually got built.

### Phase 2 — Student Shell & Discovery
- **Unit:** `HomeRepository`, `PathRepository`, `SectionsRepository`, `BooksRepository`
  — success + failure; assert **published-only** filtering, `.limit()` present, featured
  ordering.
- **Widget:** progress-bar % (green <100, gold =100); empty states render icon + Arabic
  message + action.
- **Manual:** banner carousel (active/ordered), featured books show progress, section
  counts = published only, search in books-of-section, every list empty state.
- **CC:** 21 (% vs published only), 25 (featured auto-drops), 26 (nullable banner target).

### Phase 3 — Book, Lesson, Q&A
- **Unit:** `BookRepository`, `EnrollmentRepository` (idempotent insert), `LessonRepository`,
  `LessonProgressRepository` (upsert on `user_id,lesson_id`), `QaRepository`. **Assert
  quiz fetch uses `lesson_quiz_questions_student`** and **Q&A read uses
  `student_questions_public`** (CC-18/CC-22). `drive_url` conversion unit tests.
- **Widget:** enrollment button transition `تسجيل → استمرار`; lesson 4-tab default =
  first available; MCQ selection state.
- **Manual:** CC-19 double-enroll (no duplicate row), CC-20 tap lesson without enrolling →
  enroll dialog, CC-9 audio download-then-play with airplane mode mid-download
  (partial file discarded + retry), Q&A anonymity (student B cannot see student A's identity).
- **Security spot-check:** re-run the `correct_choice` + `user_id` RLS probes as a student.
- **CC:** 1, 6, 7, 8, 9, 10, 18, 19, 20, 21, 22, 23.

### Phase 4 — Final Exam, Certificates, Achievements
- **Unit:** `ExamRepository` (fetch via `final_exam_questions_student`; submit via
  `submit_final_exam` RPC only — **no client grading**), `CertificatesRepository`.
- **Widget:** `ExamBloc` — timer countdown, resume from persisted start (CC-11), auto-submit
  on expiry (CC-12), navigator grid state, answers map.
- **Manual:** CC-11 force-close mid-exam & reopen (resume remaining / auto-submit if
  expired), CC-12 let timer expire naturally, CC-13 exhaust all attempts → locked,
  CC-17 score exactly at pass threshold (`>=`).
- **Security spot-check:** confirm exam question fetch never returns `correct_choice`.
- **CC:** 11, 12, 13, 15, 16, 17, 18.

### Phase 5 — Profile & Notifications
- **Unit:** `ProfileRepository` (change-password verify), `NotificationsRepository`
  (bulk `notification_reads`), realtime subscription wiring.
- **Widget:** unread dot + light background state; mark-all-read clears dots.
- **Manual:** edit name (email read-only), change password with current-password verify,
  notification deep-link on tap, realtime live-update (send from admin → appears without
  refresh), cancel the realtime channel on dispose.
- **CC:** (notifications delivery — N); realtime channel cleanup.

### Phase 6 — Admin Core
- **Unit:** `AdminBooksRepository`, `AdminSectionsRepository`, `AdminBannersRepository`
  — CRUD success + failure; delete-restrict error surfaced.
- **Widget:** dual status-axis badges (status / review_status); featured-cap warning.
- **Manual:** CC-3 delete section with books → restrict error, CC-4 strong delete warning,
  CC-24 featured 3–5 cap non-blocking warning, CC-26 banner with null target.
- **Security spot-check:** confirm a student JWT cannot write to admin-only tables (RLS).
- **CC:** 3, 4, 24, 26.

### Phase 7 — Admin Authoring
- **Unit:** `AdminLessonRepository` (**unified single-record save across 4 tabs**),
  quiz authoring CRUD, transactional reorder (`order_index`), final-exam settings/questions,
  `AdminQaRepository` (answer → answered + notify).
- **Widget:** the sticky `حفظ الدرس` saves all 4 tabs regardless of active tab; reorder UI.
- **Manual:** CC-5 reorder transactional, CC-14 future-only exam settings (past immutable),
  CC-16 zero-question exam locked + admin warning, admin Q&A reply notifies asker.
- **CC:** 5, 14, 16.

### Phase 8 — Hardening & White-label (FULL SWEEP)
- Re-verify **all 30 corner cases** end-to-end on the finished app.
- RTL + light/dark QA against **every** screen in `docs/screens/`.
- Performance (paginated/lazy lists, ~2s Home/Path).
- Full security pass: student cannot read any peer identity or any `correct_choice`
  anywhere.
- White-label re-deploy dry run (new Supabase → schema + migration → `--dart-define` →
  swap brand assets; CC-29 admin-recovery SQL).
- **Deliverable:** consolidated table of all 30 CCs, each marked
  **tested & passing / needs manual check / N/A**.

---

## Corner-case → phase ownership (for the Phase 8 consolidation)
| CC | Owning phase(s) | CC | Owning phase(s) |
|---|---|---|---|
| 1 | 3 | 16 | 4, 7 |
| 2 | 6 (unpublish) / 3 (enrolled view) | 17 | 4 |
| 3 | 6 | 18 | 3, 4 (+migration) |
| 4 | 6 | 19 | 3 |
| 5 | 7 | 20 | 3 |
| 6 | 3 | 21 | 2, 3 |
| 7 | 3 | 22 | 3 (+migration) |
| 8 | 3 | 23 | 3 |
| 9 | 3 | 24 | 6 |
| 10 | 3 | 25 | 2 |
| 11 | 4 | 26 | 2, 6 |
| 12 | 4 | 27 | 1 ✅ |
| 13 | 4 | 28 | 1 ✅ (trigger) |
| 14 | 7 | 29 | 8 |
| 15 | 4 | 30 | 1 ✅ |
