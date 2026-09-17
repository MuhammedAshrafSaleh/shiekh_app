# Notes Feature (الملحوظات) — Phase 2

## Progress

- [ ] **Task 1** — Per-lesson query in `NotesRepository` + lesson scope in `NotesCubit`
- [ ] **Task 2** — Optional seek callback on `NoteCard` (reuse, no second card)
- [ ] **Task 3** — Provide a lesson-scoped `NotesCubit` on the lesson screen
- [ ] **Task 4** — Notes list under the video tab (CustomScrollView / slivers)
- [ ] **Task 5** — Audio tab: shrink artwork, sliver layout, add note creation
- [ ] **Task 6** — Audio tab: notes list + seek-in-tab
- [ ] **Task 7** — Book المحفوظات → audio-only lessons seek the audio player
- [ ] **Task 8** — End-to-end verification

---

## Context

Phase 1 shipped note creation from the **video tab only**, plus a book-level
**المحفوظات** tab that lists a student's notes and (on tap) jumps into the lesson
and seeks the video. There is no note support on the **audio tab**, and there is
no way to see a lesson's notes while actually watching/listening — you have to
leave for the book screen.

Phase 2 brings the notes list **onto the lesson screen itself**, under both the
video and audio players, and adds full note support to the **audio tab** (create
+ list + seek), reusing the exact same data, card, and editor from Phase 1. It
also fixes the book **المحفوظات** seek so an **audio-only** lesson seeks its audio
player instead of doing nothing.

**No schema change. No new table/column. No `source` distinction.** A note is one
row in `lesson_notes` regardless of which tab created it, shown identically
everywhere. The existing `NotesRepository`, `NoteCard`, and `NoteEditorSheet` are
reused as-is (with one additive, backward-compatible callback on `NoteCard`).

### Route decision — NO route change needed (resolved)

The seek target is fully determined without a new route param. The lesson page
already loads the lesson and knows `lesson.hasVideo` / `lesson.hasAudio`, and tabs
are always ordered `video → audio → …`, so:

- Lesson **has video** → video tab is index 0 (default) and already receives
  `seekToSeconds` → video seeks. (unchanged)
- Lesson is **audio-only** → audio tab is index 0 (default); we forward
  `seekToSeconds` into `AudioTab.initialPositionSeconds`, which already seeks on
  load (`audio_tab.dart:132`).

The existing `?t=` seconds param is enough. No new param, no `initialIndex` change.

### Layout decision — CustomScrollView / slivers (resolved)

Both media tabs render inside a `TabBarView`. A `Column[ player, Expanded(scrollable) ]`
under a fixed-height player is a common source of `RenderFlex` overflow on short
screens, so **both tabs use a single `CustomScrollView`** instead:

- player → `SliverToBoxAdapter`
- «إضافة ملحوظة» affordance → `SliverToBoxAdapter`
- note cards → `SliverList`

No `Expanded`, no fixed height constraints around the scroll area.

### Key existing code being reused

- `NotesRepository` — `lib/features/notes/data/notes_repository.dart`
  (`getBookNotes`, `addNote`, `updateNoteText`, `deleteNote`). Add one per-lesson
  query here; do **not** fork the repo.
- `NoteCard` — `lib/features/notes/widgets/note_card.dart`. Reused; gains one
  optional callback so in-tab taps seek the local player instead of navigating.
- `NoteEditorSheet.show(...)` / `.showEdit(...)` —
  `lib/features/notes/widgets/note_editor_sheet.dart`. Reused verbatim.
- `NotesCubit` / `NotesState` — `lib/features/notes/cubit/`. Gains a lesson scope.
- VideoTab add-note flow (wasPlaying → pause → sheet → resume, guest gate) —
  `lib/features/lesson/widgets/video_tab.dart:174`. Mirrored in the audio tab.

---

## Task 1 — Per-lesson query + lesson scope in the cubit

- In `NotesRepository`, add
  `getLessonNotes(String lessonId) → Future<Either<Failure, List<LessonNoteEntity>>>`:
  same pattern as `getBookNotes` (network guard, auth guard, owner-only), filter
  `.eq('user_id', uid).eq('lesson_id', lessonId).order('position_seconds', ascending: true).limit(500)`.
- In `NotesCubit`, add a lesson scope without breaking the book scope:
  - add `String? _lessonId;`
  - `loadLessonNotes(String lessonId)` → sets `_lessonId`, clears `_bookId`,
    emits `NotesLoading()`, calls `getLessonNotes`.
  - `loadBookNotes` also clears `_lessonId` (so the two scopes never mix).
  - add private `_reload()` → reloads whichever scope is active
    (`_lessonId != null` → lesson, else `_bookId != null` → book).
  - `delete(...)` and `refreshAfterEdit()` call `_reload()` instead of hard-coding
    `loadBookNotes`. (Book screen behavior is unchanged.)
- **Files:** `lib/features/notes/data/notes_repository.dart`,
  `lib/features/notes/cubit/notes_cubit.dart`
- **Done when:** unit tests cover `getLessonNotes` success + each failure path;
  `NotesCubit` lesson-load emits Loading→Loaded, and delete/edit reload the lesson
  scope. Book screen still works (regression check).

## Task 2 — Optional seek callback on `NoteCard`

- Add `final VoidCallback? onSeek;` to `NoteCard` (default `null`).
- In `build`, `onTap: onSeek ?? () => _seekToNote(context)`. When `null`
  (book screen) behavior is identical to today; when provided (in a lesson tab)
  the tap seeks the local player and does **not** navigate.
- Edit/delete stay exactly as-is — they use `context.read<NotesCubit>()`, which
  resolves to the lesson-scoped cubit when the card is rendered in a tab.
- **Files:** `lib/features/notes/widgets/note_card.dart`
- **Done when:** book screen cards navigate as before; a card with `onSeek` fires
  the callback and never pushes a route.

## Task 3 — Lesson-scoped `NotesCubit` on the lesson screen

- Wrap the lesson content subtree (the `DefaultTabController` tree in
  `_LessonView.build`) in
  `BlocProvider<NotesCubit>(create: (ctx) => NotesCubit(ctx.read<NotesRepository>())..loadLessonNotes(widget.lessonId))`
  so both the video and audio tabs share ONE cubit and refresh in lock-step.
- Confirm `NotesRepository` is resolvable at this route (global repo used by the
  book screen; registered in `app/bloc_providers.dart`).
- **Files:** `lib/features/lesson/view/lesson_page.dart`
- **Done when:** both tabs read the same `NotesCubit` instance; it loads this
  lesson's notes once when the lesson opens.

## Task 4 — Notes list under the video tab (CustomScrollView / slivers)

- In `video_tab.dart`, change the `_Status.ready` branch from
  `Column[ player, affordance ]` to a single `CustomScrollView` with slivers:
  - `SliverToBoxAdapter` → the player (`Center(AspectRatio(16/9, Chewie))`).
  - `SliverToBoxAdapter` → the existing `_AddNoteAffordance`.
  - `SliverList` → the note cards.
  - **No `Expanded`, no fixed height constraints** around the scroll view.
- Drive the sliver content with `BlocBuilder<NotesCubit, NotesState>`:
  - Loading/Initial → small inline spinner (`SliverToBoxAdapter`).
  - Error → compact inline error text (not the full-page `SheikhyErrorState`).
  - Loaded, empty → short quiet line, e.g. *«لا توجد ملحوظات لهذه المحاضرة بعد»*
    (no big illustration — it sits inside a scrollable tab).
  - Loaded, non-empty → `SliverList` of
    `NoteCard(note: n, bookId: widget.bookId!, onSeek: () => _videoController?.seekTo(Duration(seconds: n.positionSeconds)))`.
    Cards are already sorted ascending by the repo.
- After `_openNoteEditor()`'s `await NoteEditorSheet.show(...)` returns (add flow),
  call `context.read<NotesCubit>().refreshAfterEdit()` so the new note appears
  immediately. (Edit/delete already refresh via the card.)
- **Files:** `lib/features/lesson/widgets/video_tab.dart`
- **Done when:** below the video, the current user's notes for this lesson show
  ascending; add/edit/delete update the list with no stale UI; tapping a card
  seeks the video; empty state is the quiet inline line; **on a short 16:9 phone
  at the smallest supported height there is no `RenderFlex` overflow and nothing
  is cut off.**

## Task 5 — Audio tab: shrink artwork, sliver layout, add note creation

- Add `final String? lessonId;` and `final String? bookId;` to `AudioTab`
  (nullable, like VideoTab); pass them from `lesson_page.dart`.
- Rebuild the **player-state** view (`_AudioPlayer`) as a single `CustomScrollView`
  with slivers (same structural approach as Task 4) — **not** a centered Column in
  a `SingleChildScrollView`:
  - `SliverToBoxAdapter` → shrunken artwork circle (~120×120, icon ~48; down from
    180/72), title, sheikh name, slider, time row, play/pause button. Keep all
    colors/spacing/component styles (`AppColors`, `AppSpacing`, slider theme, play
    button). Drop the `MainAxisAlignment.center` / `minHeight` centering.
  - `SliverToBoxAdapter` → the same `_AddNoteAffordance` used in the video tab.
  - `SliverList` → note cards (Task 6).
  - No `Expanded`, no fixed height constraints.
- The affordance + notes list render **only in the player state**. Do NOT render
  them in the `checking` / `idle` / `downloading` / `error` states.
- Only render the affordance when
  `!previewMode && lessonId != null && bookId != null` (same guard as video).
- Wire the affordance `onTap` to a new `_openNoteEditor()` in `_AudioTabState`
  that mirrors the video flow exactly:
  1. `final wasPlaying = _status == _AudioStatus.playing;` (capture BEFORE pause)
  2. guest gate: same `AuthCubit` check + `/signup?returnTo=…&autoEnrollBookId=…`
     redirect and abort as `video_tab.dart:183`.
  3. `final seconds = _player.position.inSeconds;`
  4. `await _player.pause();`
  5. `await NoteEditorSheet.show(context, lessonId: lessonId!, bookId: bookId!, positionSeconds: seconds);`
  6. `if (wasPlaying && mounted) await _player.play();`
  7. `if (mounted) context.read<NotesCubit>().refreshAfterEdit();`
- **Files:** `lib/features/lesson/widgets/audio_tab.dart`,
  `lib/features/lesson/view/lesson_page.dart`
- **Done when:** artwork is smaller, the player view is a `CustomScrollView`,
  «إضافة ملحوظة» opens the same sheet with the audio position auto-captured,
  pause/resume honors `wasPlaying`, guests hit the sign-in gate, and the affordance
  is absent in checking/idle/downloading/error states.

## Task 6 — Audio tab: notes list + seek-in-tab

- Under the audio affordance, render the same `BlocBuilder<NotesCubit>`-driven
  `SliverList` of `NoteCard`s as Task 4, with
  `onSeek: () => _player.seek(Duration(seconds: n.positionSeconds))`.
- Same states: inline spinner / inline error / quiet empty line / ascending cards.
- **Files:** `lib/features/lesson/widgets/audio_tab.dart`
- **Done when:** the audio tab shows this lesson's notes; tapping a card seeks the
  **audio** player (no cross-tab jump); list stays in sync with add/edit/delete;
  **no overflow on a short 16:9 screen.**

## Task 7 — Book المحفوظات → audio-only lessons seek audio

- In `lesson_page.dart`, when building the `AudioTab`, forward the incoming seek to
  the audio player for audio-only lessons:
  `initialPositionSeconds: lesson.hasVideo ? audioResumeSeconds : (widget.seekToSeconds ?? audioResumeSeconds)`.
- For lessons that have video, the video tab (index 0) keeps receiving
  `seekToSeconds` and audio keeps its own resume position — matching the rule
  “has video → open video tab and seek video; audio-only → open audio tab and seek
  audio.” The default tab is already index 0 in both cases, so no `initialIndex`
  change is required.
- `NoteCard`'s book-screen navigation (`/lessons/{id}?bookId=…&t=…`) is unchanged.
- **Files:** `lib/features/lesson/view/lesson_page.dart`
- **Done when:** tapping a note in المحفوظات for an audio-only lesson opens the
  lesson on the audio tab already seeked to that position (resume snackbar shows);
  video lessons behave exactly as before.

## Task 8 — End-to-end verification

Run: `flutter analyze`, `dart format lib/`, `flutter test`, then
`flutter run --dart-define-from-file=dart_define.json`.

Manual, on a lesson with **both** video and audio, and one **audio-only** lesson,
including a **short 16:9 phone at the smallest supported height**:

1. **Video tab:** add a note → it appears in the list below immediately, ascending
   by timestamp; edit text → updates in place; delete → confirm dialog → removed;
   tap a card → video seeks; empty lesson shows the quiet inline line, not a big
   illustration. No `RenderFlex` overflow; nothing cut off.
2. **Audio tab:** artwork is smaller and the player view scrolls; «إضافة ملحوظة»
   captures the current audio position; audio pauses for the sheet and resumes only
   if it was playing; add/edit/delete keep the list fresh; tap a card → audio seeks
   (never jumps to video); affordance/list absent in checking/idle/downloading/
   error states. No overflow on the short screen.
3. **Shared data:** a note created in the audio tab shows identically in the video
   tab and in the book المحفوظات tab (one dataset, no source distinction).
4. **Guest:** creating a note from the audio tab routes to `/signup` with
   `returnTo` + `autoEnrollBookId`, same as video.
5. **Book المحفوظات seek:** tapping a note for an audio-only lesson opens the audio
   tab already seeked; tapping a note for a video lesson opens the video tab and
   seeks video.
6. **Offline/error:** loading notes offline shows the inline error; repo network
   guard returns the Arabic offline message.

---

## OUT of scope

- Any schema change (unless you justify it to me first and I approve).
- A separate card or editor design for audio.
- Any change to the book's المحفوظات tab beyond the seek-target rule above.
- Everything already listed as out of scope in the Phase 1 plan document —
  that list still applies in full.

---

## Open question — RESOLVED

**Audio notes visibility before the file is downloaded.** RESOLVED: **player-state
only.** The «إضافة ملحوظة» affordance and the notes list appear only once the audio
player is loaded. They are NOT rendered in the `checking` / `idle` / `downloading`
/ `error` states.

---

## Files summary

**Modified**
- `lib/features/notes/data/notes_repository.dart` — `getLessonNotes`
- `lib/features/notes/cubit/notes_cubit.dart` — lesson scope + `_reload`
- `lib/features/notes/widgets/note_card.dart` — optional `onSeek`
- `lib/features/lesson/view/lesson_page.dart` — provide `NotesCubit`; pass
  `lessonId`/`bookId` to `AudioTab`; audio-only seek forwarding
- `lib/features/lesson/widgets/video_tab.dart` — sliver layout, notes list,
  refresh-after-add
- `lib/features/lesson/widgets/audio_tab.dart` — smaller artwork, sliver layout,
  add-note flow, notes list + seek

**New**
- `docs/features/notes-feature-phase2.md` (this document)
- test updates for `getLessonNotes` / lesson-scope cubit

**No** migration, no new model, no new route param.
