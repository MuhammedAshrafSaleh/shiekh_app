# Practice Exams — «اختبر نفسك»

Adds a fully isolated student practice-exam feature: build a timed (optional)
exam from multiple completed lectures, with randomized/shuffled questions,
server-side grading, a scored result + review, and attempt history. Includes an
admin screen to manage the loading-screen quotes. Also fixes a pre-existing
admin bug (deleting a quiz question imported into a final exam).

Branch: `feature/practice-exams` → `master`

## Feature summary

**Student**
- New **middle bottom-nav tab** (raised circular button) — RTL order:
  الرئيسية · مساري · **اختبر نفسك** · إنجازاتي · حسابي.
- **Setup**: lectures grouped by book (accordion, select-all per book,
  cross-book selection); only lectures whose official quiz was submitted are
  eligible. Question count slider (min 20, max `min(100, available)`), block +
  «اختار محاضرات أكتر» when < 20. Optional timer (15–120 min, step 5).
- **Distribution** (pure, unit-tested): even split across lectures, random
  remainder, short-lecture backfill, question-order shuffle. Choices always
  display a/b/c/d.
- **Loading screen**: cycles admin-managed motivational quotes (~3s each, with
  progress bar); «ابدأ الآن» appears after the first quote; question pool is
  prefetched in parallel so the exam opens instantly; falls back to 3 seeded
  defaults when no quotes are active.
- **Exam runner**: MCQ + question map, optional wall-clock timer with
  auto-submit, leave-confirmation (nothing saved), failed-submit keeps answers
  with retry, double-submit guard.
- **Result + history**: total score, per-lecture breakdown, per-question review
  (reuses the shared quiz review widget, each question labeled with its source
  lecture). History keeps the last 10 attempts; tapping one reopens the review.

**Admin**
- **Loading-quotes CRUD** (`/admin/loading-quotes` + dashboard tile): list with
  drag-reorder, per-row active toggle, edit, delete (shared confirm dialog),
  add/edit form (text required ≤200 with live counter; source optional ≤60);
  info banner when none active.

**Isolation & security**
- Practice performs **no client-side writes**; the only write path is the
  `SECURITY DEFINER` `submit_practice_attempt` RPC. No writes to
  `lesson_progress`, `lesson_quiz_attempts`, `final_exam_attempts`,
  achievements, or stats.
- **CC-18**: the question pool is read from the answer-free
  `lesson_quiz_questions_student` view; `correct_choice` is only ever returned
  by the grading/review RPCs **after** submission.

## Migrations to run (Supabase SQL editor, in order)

> Already applied on the primary project. Required for any fresh deploy
> (e.g. a second sheikh's project), after the base schema + `0001`–`0019`.

1. **`supabase/migrations/0020_practice_exams.sql`** — new in this PR.
   `practice_attempts` table (RLS: select-own only; inserts via RPC) +
   keep-last-10 trigger; `loading_quotes` table (+ RLS + 3 seeded defaults);
   RPCs `get_practice_eligible_lessons`, `submit_practice_attempt`,
   `get_practice_attempt_review` (all `SECURITY DEFINER`, `search_path=public`,
   `revoke … from anon`, `grant … authenticated`).
2. **`supabase/migrations/0021_final_exam_source_fk_set_null.sql`** — already
   merged to `master` via the FK fix; included here for completeness. Switches
   `final_exam_questions.source_quiz_question_id` to `ON DELETE SET NULL`.

No new packages. No changes to existing tables/views/RPCs from `0020`.

## Screenshots checklist

- [ ] Bottom nav with the raised «اختبر نفسك» center button (light + dark)
- [ ] Setup: book accordion, select-all, count slider, timer toggle
- [ ] Block state «اختار محاضرات أكتر» (< 20 available)
- [ ] Empty state «لم تُكمل أي اختبار محاضرة بعد»
- [ ] Loading screen (quote + progress + «ابدأ الآن»)
- [ ] Exam runner (MCQ + question map + timer)
- [ ] Leave-confirmation dialog
- [ ] Result (score + per-lecture breakdown + review with lecture labels)
- [ ] History list + reopened review
- [ ] Review showing a «هذا السؤال تم حذفه» tombstone (deleted question)
- [ ] Admin loading-quotes list (reorder/toggle), form with counters, no-active banner

## Test plan

**Automated** (`flutter test test/features/practice/ test/core/widgets/quiz_review_list_test.dart test/features/admin/admin_loading_quotes_test.dart test/features/admin/admin_lesson_delete_test.dart`)
- Distribution: even split, remainder (25/10), short-lecture backfill, clamping, determinism, no duplicates.
- Repository: offline/auth guards, Postgres→Failure mapping, entity parsing incl. tombstone.
- Setup cubit: grouping, select-all/clear, cross-book mixing, count re-clamp.
- Exam bloc: build 20, pool failure, answer/navigate, submit success, submit-failure-keeps-answers + retry (manual & auto), double-submit guard, timer-off → null limit.
- Review widget: normal / lecture chip / tombstone.
- Admin quotes cubit + repo: load/create/update/delete (success + failure keeps list), toggle, reorder, Arabic error mapping.

**Manual (device, done)**
- Complete ≥2 lesson quizzes → build & take a practice exam (with/without timer);
  timeout auto-submit; leave-confirm discards; offline submit → retry.
- Result + per-lecture breakdown + review; reopen from history (date + duration).
- Delete a quiz question imported into a final exam → succeeds, exam keeps its copy; offline delete keeps the list with Arabic SnackBar.
- Admin quotes: add/edit (counters), reorder persistence, toggle, delete, no-active banner; student loading screen reflects changes and shows defaults when none active.
- Back navigation from result/history always lands on the اختبر نفسك tab; history refreshes after submit.

## Notes / known
- `onReorder` deprecation (Flutter ≥3.41-pre) in the quotes list — same API the
  existing onboarding admin screen uses; info-level only.
- 9 pre-existing truncated-test failures on `master` (see `docs/RECOVERY_AUDIT.md`)
  are unrelated to this feature and unchanged by it; no new failures introduced.

## Commits
```
feat(practice): add practice exams migration (0020)
feat(practice): phase 2 - question distribution logic + tests
feat(practice): phase 3 - models + repository + tests
feat(practice): phase 4 - nav tab + setup screen
feat(practice): group setup lessons by book
feat(practice): phase 5 - loading screen + exam runner
feat(practice): phase 6 - result + history review
feat(practice): phase 7 - admin loading-quotes CRUD
(+ merges of master carrying fix/quiz-question-delete-fk)
```
