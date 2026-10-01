# Recovery Audit — truncation damage from commit `022f2f8`

**Context:** commit `022f2f8` ("recover: restore Sept 18-22 work from Claude Code
session logs (post-last-push changes)") truncated many files instead of fully
restoring them. Some were later re-fixed by subsequent commits; others are **still
truncated today**. This document captures the surviving damage so it can be picked
up in a fresh session.

Audited on the `fix/system-nav-insets` branch. Comparison baseline is `022f2f8^`
(the state immediately before the recovery commit).

## TL;DR
- **`lib/` production Dart code: intact.** Every file is within normal size of its
  pre-recovery version and `flutter analyze lib/` is clean (a truncated `.dart`
  wouldn't compile). No production Dart truncation survives.
- **Migrations + authoritative schema doc: still truncated** (never restored).
  Already deployed to live Supabase, so the running app is unaffected — this is a
  **repo-integrity** issue (re-provisioning would fail; `docs/schema.sql` is
  incomplete).
- **7 test files still truncated** → full `flutter test` is not green.
- **No files were deleted** by the recovery commit.

## Non-test files still truncated today (NOT restored)

| File | Type | pre `022f2f8^` | now | State |
|---|---|---:|---:|---|
| `supabase/migrations/0001_app_support.sql` | Migration (critical) | 531 | 47 | Cut mid-file — missing `student_questions_public` view + `submit_final_exam` / `grade_lesson_quiz` RPCs. CLAUDE.md flags this as required for exam/quiz/Q&A. |
| `supabase/migrations/0006b_notification_scoping.sql` | Migration | 319 | 2 | Gutted to header comment only |
| `supabase/tests/0011_ai_question_generation_test.sql` | SQL test | 168 | 3 | Gutted |
| `supabase/tests/0006b_notification_scoping_test.sql` | SQL test | 117 | 4 | Gutted |
| `docs/schema.sql` | Doc (authoritative) | 511 | 129 | Cut mid-table (`final_exam_attempts`) |
| `docs/Supabase_Setup_Guide.md` | Doc | 877 | 29 | Truncated |
| `plan.md` | Doc | 205 | 40 | Truncated |

These should be restorable cleanly from `022f2f8^` (they were the deployed
versions at that point). Suggested recovery per file:
`git show 022f2f8^:<path> > <path>` then verify completeness.

## Test files still truncated (blocking a green `flutter test`)

| File | pre `022f2f8^` | now |
|---|---:|---:|
| `test/features/admin/admin_phase7_cubits_test.dart` | 1434 | 45 |
| `test/features/exam/exam_bloc_test.dart` | 571 | 29 |
| `test/features/lesson/lesson_repository_test.dart` | 358 | 62 |
| `test/features/admin/admin_book_repository_test.dart` | 279 | 79 |
| `test/features/admin/admin_section_repository_test.dart` | 231 | 149 |
| `test/features/admin/admin_widgets_test.dart` | 201 | 49 |
| `test/features/admin/admin_dashboard_repository_test.dart` | 165 | 79 |

**Reconciliation notes for restoration:**
- Restore from `022f2f8^`, then reconcile against the **current** API — several
  files predate later refactors and the bank-import redesign.
- `admin_phase7_cubits_test.dart` will reference the now-removed cubit methods
  `AdminExamCubit.getBankQuestions` and `AdminLessonFormCubit.getBankQuestions`
  (removed in the drill-down redesign, commit `72b7671`). Those cases must be
  **deleted or rewritten against `QuestionBankRepository`** — not revived as-is.
- Expect drifted Arabic copy / added dependencies (e.g. `SoundService` provider),
  as was needed for `test/widget_test.dart`.

## Already fixed (committed on this branch)
- `test/features/profile/profile_repository_test.dart` — restored (commit `92e4112`).
- `test/widget_test.dart` — restored + reconciled (SoundService provider; updated
  login/signup/forgot-password copy after the design overhaul) (commit `92e4112`).

## Runtime drift (not truncation) — needs a decision, not an auto-fix
- `test/features/admin/admin_cubits_test.dart` → test
  "AdminDashboardCubit deleteBook triggers load (emits Loading → Loaded) on delete
  success". The cubit now emits `AdminDashboardDeleteSuccess()` **before**
  `Loading → Loaded`; the test still expects only `Loading → Loaded`.
  **Before changing the test:** check the cubit's git history — if the
  `DeleteSuccess` emission is an intentional change (e.g. to drive a success
  snackbar), update the test to expect it (`emitsThrough` / include DeleteSuccess).
  If it came from the recovery commit or looks accidental, fix the cubit, not the
  test.

## Stray file to remove
- `test/tmp_confirm_test.dart` (added by the recovery commit, Sept 27) — a leftover
  temp test. Currently passes but should be deleted as cleanup.

## Plan for the fresh session (Option 1, previously approved before pausing)
1. **Await decision** on the non-test truncations (migrations / `schema.sql` /
   docs / `plan.md`) — user paused restoration of anything outside `test/`.
2. Restore the 7 truncated test files from `022f2f8^`; reconcile with the current
   API; delete/rewrite the removed-bank-method cases against `QuestionBankRepository`.
3. Resolve the `admin_cubits_test` drift per the history check above.
4. Delete `test/tmp_confirm_test.dart`.
5. Goal: full `flutter test` green, as one separate commit for the test restoration.
