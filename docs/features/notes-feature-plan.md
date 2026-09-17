# Feature: الملحوظات (Lecture Video Notes)

> This document is the full implementation plan. It is checked in so a fresh
> session with no prior context can pick it up and implement it correctly.

## Progress

- [x] **Task 1** — Data layer: `0013_lesson_notes.sql` migration (reviewed + run)
- [x] **Task 2** — Model + repository + DI + tests
- [x] **Task 3** — Add-note flow (VideoTab affordance, pause/resume, editor sheet)
- [x] **Task 4** — Seek-on-open (router `t` param → VideoTab initial position)
- [x] **Task 5** — Notes tab UI (Level 1 list, Level 2 pushed route, cards, edit/delete)
- [x] **Task 6** — Book screen tab restructure (الدروس / المحفوظات)

---

## Context

Students watch lecture videos but cannot capture a thought tied to a specific
moment, nor revisit those moments later. This feature lets a student attach a
short **plain-text** note to the **current video position** from under the
player, then browse all their notes for a book — grouped by lecture — and tap any
note to reopen that lecture and **seek to the exact second**. Seek-to-moment is
the core value; everything else supports it.

Confirmed UX decisions:
- **Book screen:** header + progress/description stay above a new `TabBar`; the
  tabs split only the lower area into **الدروس** (existing lessons list + exam card
  + CTA) and **المحفوظات** (notes).
- **Level-2 note order:** by `position_seconds` ascending (chronological).
- **Level 1 → Level 2:** a **pushed GoRoute** (see Task 5) — not in-tab state.
- **Guests:** the "إضافة ملحوظة" affordance stays visible; tapping it (while a
  guest) shows the existing sign-up gate instead of the editor.

---

## OUT of scope (verbatim — do not drift beyond this)

- Bookmarks / saved positions without text — a completely separate feature.
- PDF or any other export.
- Rich text, formatting, colors, tags, categories.
- Sharing notes between users.
- Search across notes.
- Editing the timestamp.
- A global "all my notes" screen outside the book.
- Notes on anything other than lecture videos.

---

## Open question — RESOLVED before Task 3

**Q: Does an anonymous (guest) session in this app have a real Supabase
`auth.uid()`?**

**A: Yes.** Guests are created via `_client.auth.signInAnonymously()`
(`lib/features/auth/data/auth_repository.dart:58-64`); the JWT carries
`is_anonymous = true` and a real `auth.uid`, and `AuthState.isGuest` is derived
from `user.isAnonymous` (`lib/features/auth/cubit/auth_state.dart:26-28`). The
`on_auth_user_created` trigger creates the `public.users` row for every auth user,
so the `lesson_notes.user_id → users.id` FK is satisfiable for guests too.

**Consequence / decision:** RLS (`auth.uid() = user_id`) would technically let a
guest own notes, but per product direction we **gate note creation behind a real
account**. The affordance stays visible; tapping it as a guest opens the existing
sign-up gate (conversion keeps the same `auth.uid`, so any future guest notes
would survive conversion — but we do not create guest notes in v1).

---

## Architecture reference (verified against the codebase)

- Video: `VideoTab` (`video_player` + `chewie`, not iframe) holds `_videoController`;
  reads position via `_videoController.value.position.inSeconds`; seeks via
  `initialPositionSeconds` on init — `lib/features/lesson/widgets/video_tab.dart:99-105,158-160`.
- Lesson route `/lessons/:id?bookId=` builds `LessonPage` — `lib/app/router.dart:361`.
- Book screen `_BookDetailsView` = single `CustomScrollView`, no tabs —
  `lib/features/books/view/book_details_page.dart:329-459`. `BookDetailsLoaded`
  already carries `lessons` ordered by `order_index`
  (`LessonWithProgressEntity`) — reused for lecture titles/order.
- The book page has a route listener `_handleRouteChange` that already detects
  returning from `/lessons/` and refetches progress —
  `book_details_page.dart:139-153` (extend it for notes staleness).
- Models = plain `Equatable` + `fromJson`/`copyWith` (no freezed) — e.g.
  `lib/models/lesson_progress_entity.dart`.
- Repository pattern: ctor `(SupabaseClient, ConnectivityCubit)`, `_checkNetwork`
  guard, `try/catch` on `PostgrestException`/`SocketException`, `Logger`,
  `Either<Failure,T>` — `lib/features/books/data/book_repository.dart:16-45`.
- Bottom-sheet-with-own-cubit pattern: `AskQuestionSheet` + `AskQuestionCubit`
  via `BlocProvider` inside the sheet — `lesson_page.dart:231-247`.
- Guest sign-up gate helper: `_showGuestSignupGate` — `book_details_page.dart:34-106`.
- Time format: `formatMediaDuration` (mm:ss + LTR-mark bidi guard) —
  `lib/core/utils/media_duration.dart`.

---

## Task 1 — Data layer: `0013_lesson_notes.sql`

- [ ] Add migration `supabase/migrations/0013_lesson_notes.sql` (matches 0012 style).
- [ ] Review SQL together; **user runs it** in the Supabase SQL Editor.

**Full migration SQL (inline):**

```sql
-- ============================================================
-- Sheikhy — Migration 0013_lesson_notes.sql   (Student lecture notes)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: let a student attach a short plain-text note to a specific second of
-- a lecture video, and browse their notes per book. book_id is STORED (not just
-- derivable) so "all my notes in this book" is a single indexed query with no
-- join to lessons. Strictly owner-only (private notes).
-- ============================================================

create table if not exists public.lesson_notes (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references public.users(id)   on delete cascade,
  lesson_id        uuid not null references public.lessons(id) on delete cascade,
  book_id          uuid not null references public.books(id)   on delete cascade,
  note_text        text not null check (char_length(btrim(note_text)) between 1 and 1000),
  position_seconds int  not null default 0 check (position_seconds >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.lesson_notes is
  'ملحوظات الطالب النصية المرتبطة بلحظة زمنية في فيديو المحاضرة.';

create index if not exists idx_lesson_notes_user_book
  on public.lesson_notes(user_id, book_id);
create index if not exists idx_lesson_notes_user_lesson
  on public.lesson_notes(user_id, lesson_id, position_seconds);

alter table public.lesson_notes enable row level security;

-- Table privileges (RLS narrows these row-by-row).
grant select, insert, update, delete on public.lesson_notes to authenticated;

-- RLS — strictly owner-only for every operation.
drop policy if exists "lesson_notes_select_own" on public.lesson_notes;
create policy "lesson_notes_select_own" on public.lesson_notes
  for select using (auth.uid() = user_id);

drop policy if exists "lesson_notes_insert_own" on public.lesson_notes;
create policy "lesson_notes_insert_own" on public.lesson_notes
  for insert with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_update_own" on public.lesson_notes;
create policy "lesson_notes_update_own" on public.lesson_notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "lesson_notes_delete_own" on public.lesson_notes;
create policy "lesson_notes_delete_own" on public.lesson_notes
  for delete using (auth.uid() = user_id);

-- Auto-maintain updated_at (existing shared function).
drop trigger if exists trg_lesson_notes_updated_at on public.lesson_notes;
create trigger trg_lesson_notes_updated_at before update on public.lesson_notes
  for each row execute function public.set_updated_at();
```

**Files:** `supabase/migrations/0013_lesson_notes.sql`
**Done when:** SQL reviewed; user has run it; a manual insert as an authenticated
user succeeds and a second account cannot select it (RLS verified as the
authenticated role, not postgres).

---

## Task 2 — Model + repository + DI + tests

- [ ] `LessonNoteEntity` — plain `Equatable` (`id, userId, lessonId, bookId,
      noteText, positionSeconds, createdAt, updatedAt`) with `fromJson`,
      `copyWith`, `props` (mirror `lesson_progress_entity.dart`).
- [ ] `NotesRepository(SupabaseClient, ConnectivityCubit)` with the house
      guard/try-catch/Logger pattern and `Either` returns:
  - `getBookNotes(bookId)` → `List<LessonNoteEntity>`
    (`.eq('user_id', uid).eq('book_id', bookId).order('position_seconds')`, `.limit()`).
  - `addNote({lessonId, bookId, positionSeconds, text})` → `LessonNoteEntity`
    (insert with `user_id = currentUser.id`, `.select().single()`).
  - `updateNoteText(noteId, text)` → `LessonNoteEntity`.
  - `deleteNote(noteId)` → `Unit`.
- [ ] Register `NotesRepository` in `lib/app/bloc_providers.dart`
      (`NotesRepository(supabase, connectivity)`).
- [ ] Unit tests: success + each failure path (`ServerFailure`,
      `NetworkFailure`, `AuthFailure` when no user) per method.

**Files:** `lib/models/lesson_note_entity.dart`,
`lib/features/notes/data/notes_repository.dart`, `lib/app/bloc_providers.dart`,
`test/features/notes/notes_repository_test.dart`
**Done when:** `flutter analyze` clean; `flutter test` green.

---

## Task 3 — Add-note flow (under the video player)

- [ ] `NoteEditorCubit` + state (`NoteEditorInitial / NoteEditorSaving /
      NoteEditorSuccess(note) / NoteEditorError(message)`); `save(...)` (add) and
      `updateText(...)` (edit). No navigation/snackbar in the cubit.
- [ ] `NoteEditorSheet` (shared add/edit): multiline `TextField` (controller in
      State, disposed) + "حفظ" button; disable + spinner while `NoteEditorSaving`;
      green SnackBar on success then auto-close; red SnackBar on error. Provides
      its own `NoteEditorCubit` via `BlocProvider` (mirror `AskQuestionSheet`),
      `isScrollControlled: true`, keyboard-safe. **No timestamp field.**
- [ ] `VideoTab`: add `lessonId` and `bookId` params. In the `_Status.ready`
      branch render an **"إضافة ملحوظة"** affordance (icon + label, ≥48dp) under
      the `AspectRatio`. Hidden only when `previewMode` (admin preview).
- [ ] On tap:
  1. `final bool wasPlaying = _videoController!.value.isPlaying;`  **(capture first)**
  2. **Guest check:** if `AuthCubit` state is a guest, show the existing sign-up
     gate and return (do not pause/open the sheet).
  3. `final seconds = _videoController!.value.position.inSeconds;`
  4. `await _videoController!.pause();`
  5. `await showModalBottomSheet(... NoteEditorSheet(mode: add, lessonId, bookId,
     positionSeconds: seconds))`.
  6. After the sheet future resolves (closed OR saved): **resume only if
     `wasPlaying`** → `if (wasPlaying) await _videoController!.play();`. Never call
     `play()` unconditionally.
- [ ] Wire params where `VideoTab` is built (`lesson_page.dart:266`) →
      `lessonId: widget.lessonId, bookId: widget.bookId`.

**Files:** `lib/features/notes/cubit/note_editor_cubit.dart` (+ state),
`lib/features/notes/widgets/note_editor_sheet.dart`,
`lib/features/lesson/widgets/video_tab.dart`,
`lib/features/lesson/view/lesson_page.dart`
**Done when:** opening the sheet pauses the video; timestamp is auto-captured (no
editable field); saving shows a green SnackBar and closes; the video resumes
**only if it was playing** before; a guest sees the sign-up gate instead.

---

## Task 4 — Seek-on-open

- [ ] `/lessons/:id` builder (`router.dart:361`): read `t`
      (`int.tryParse(state.uri.queryParameters['t'] ?? '')`) → pass
      `seekToSeconds` to `LessonPage`.
- [ ] `LessonPage` → `_LessonView`: use `widget.seekToSeconds ?? videoResumeSeconds`
      as `VideoTab.initialPositionSeconds` (`lesson_page.dart:256,269`). Existing
      `VideoTab._load()` already seeks on init — no player change.

**Files:** `lib/app/router.dart`, `lib/features/lesson/view/lesson_page.dart`
**Done when:** navigating to `/lessons/$id?bookId=$b&t=125` opens the lecture with
the video positioned at 125s.

---

## Task 5 — Notes tab UI (Level 1 + Level 2)

- [ ] `NotesCubit` + state (`NotesInitial / NotesLoading /
      NotesLoaded(List<LessonNoteEntity>) / NotesError`). `loadBookNotes(bookId)`;
      `delete(noteId, bookId)` and `editedText(...)` refetch after mutation.
- [ ] **Level 1** — `NotesTab` (mounted in the المحفوظات tab): from `NotesLoaded`,
      intersect notes with the already-ordered `lessons` (from `BookDetailsLoaded`,
      passed in) → for each lecture with ≥1 note show `NotesLectureTile` (title +
      "n ملحوظة/ملحوظات"), styled like `LessonListItem`, ordered by `order_index`.
- [ ] **Level 2 — pushed GoRoute** `/books/:id/notes/:lessonId` (child of
      `/books/:id`), lecture title passed via `extra`. Its builder provides a
      `NotesCubit` that `loadBookNotes(bookId)` and the page filters to
      `lessonId`. **Android/system back pops this route → returns to the book
      screen's المحفوظات tab (Level 1)** — no conflict with the book page's
      `PopScope` because Level 2 is a separate route, not in-tab state.
- [ ] `NoteCard`: note text + timestamp via `formatNoteTimestamp` (mm:ss, or
      hh:mm:ss ≥ 1h). Tap card → `context.push('/lessons/$lessonId?bookId=$bookId&t=$seconds')`
      (Task 4). Actions: **edit** → `NoteEditorSheet(mode: edit, note)` (text only)
      then refetch; **delete** → confirm `AlertDialog` → `NotesCubit.delete` →
      green SnackBar → refetch.
- [ ] Empty states (`SheikhyEmptyState`): book has no notes ("لا توجد ملحوظات" /
      "أضف ملحوظة أثناء مشاهدة المحاضرة لتظهر هنا"); Level-2 lecture emptied of its
      last note → pop back to Level 1 (or show a per-lecture empty message).
- [ ] Loading = centered spinner; Error = `SheikhyErrorState` + retry; offline via
      `_checkNetwork` → `NetworkFailure`.
- [ ] Add `formatNoteTimestamp(Duration)` to `media_duration.dart` (reuse the
      `_ltrMark` guard; render with `textDirection: TextDirection.ltr`).

**Files:** `lib/features/notes/cubit/notes_cubit.dart` (+ state),
`lib/features/notes/view/notes_tab.dart`,
`lib/features/notes/view/lecture_notes_page.dart` (Level 2),
`lib/features/notes/widgets/note_card.dart`,
`lib/features/notes/widgets/notes_lecture_tile.dart`,
`lib/core/utils/media_duration.dart`, `lib/app/router.dart`
**Done when:** a lecture with notes shows the right count; drilling in shows cards
in ascending-timestamp order with correct mm:ss/hh:mm:ss; system back returns to
Level 1; edit persists; delete confirms then removes; empty states render.

---

## Task 6 — Book screen tab restructure

- [ ] Provide `NotesCubit` for `/books/:id` by wrapping `BookDetailsPage` in a
      `MultiBlocProvider` (`BookDetailsCubit` + `NotesCubit`) so the book page can
      also `context.read<NotesCubit>()`.
- [ ] Restructure `_BookDetailsView` into `DefaultTabController(length: 2)` +
      `NestedScrollView`: `headerSliverBuilder` = existing `_HeritageSliverHeader`
      + `_BookMeta` + `OrnamentDivider` + a pinned `TabBar`
      (`SliverPersistentHeader`, labels **الدروس** / **المحفوظات**, styled like
      `_LessonTabBar`). `body` = `TabBarView`:
  - **الدروس:** current lessons `SliverList` + `FinalExamCard` + bottom
    `_ActionButton`, logic unchanged.
  - **المحفوظات:** `NotesTab` (receives ordered `state.lessons`).
- [ ] **Staleness (both mechanisms):**
  - When the المحفوظات tab becomes the active tab, call
    `context.read<NotesCubit>().loadBookNotes(bookId)` (TabController listener).
  - Extend the existing `_handleRouteChange` (`book_details_page.dart:139-153`):
    on return from a `/lessons/` route, also
    `context.read<NotesCubit>().loadBookNotes(bookId)` so a note added on the
    lesson screen appears immediately.

**Files:** `lib/app/router.dart`, `lib/features/books/view/book_details_page.dart`
**Done when:** the المحفوظات tab lists notes correctly; a note added from the
lesson screen appears after returning; **AND the existing الدروس tab behaves
exactly as before — verify scrolling, the collapsing header, the final-exam card,
and the bottom action button — before considering this task complete.**

---

## Files summary

**Create:** `supabase/migrations/0013_lesson_notes.sql`;
`lib/models/lesson_note_entity.dart`;
`lib/features/notes/data/notes_repository.dart`;
`lib/features/notes/cubit/{notes_cubit,notes_state,note_editor_cubit,note_editor_state}.dart`;
`lib/features/notes/view/{notes_tab,lecture_notes_page}.dart`;
`lib/features/notes/widgets/{note_editor_sheet,note_card,notes_lecture_tile}.dart`;
`test/features/notes/notes_repository_test.dart`

**Modify:** `lib/app/bloc_providers.dart`; `lib/app/router.dart`;
`lib/features/lesson/widgets/video_tab.dart`;
`lib/features/lesson/view/lesson_page.dart`;
`lib/features/books/view/book_details_page.dart`;
`lib/core/utils/media_duration.dart`

---

## End-to-end verification

- `flutter analyze` clean; `flutter test` green.
- Run: `flutter run --dart-define-from-file=dart_define.json`.
- Add note: video pauses on sheet open; timestamp auto-captured (not editable);
  save → green SnackBar; resume **only if it was playing**.
- Guest: affordance visible; tap → sign-up gate (no sheet).
- المحفوظات tab: lecture + count correct; note added from lesson screen appears
  after returning; drill-in cards ascending timestamp; mm:ss / hh:mm:ss correct.
- Tap card → lecture opens sought to that second.
- Edit persists; delete confirms then removes; empty states show.
- RLS: notes per-user (second account can't see them); offline → network message.
- الدروس tab unchanged (scroll, collapsing header, exam card, action button).
