# Browse Books by LEVEL (view-mode filter) — Implementation Plan

## Context

Students currently browse books by **scientific section** only. The client wants
a second, parallel way to browse — by **academic LEVEL** (e.g. "السنة التمهيدية",
"المستوى الأول"). Levels are admin-managed, cross-cutting (one level can group
books from different sections), and a book belongs to **at most one** level (or
none). Sections, books, and lectures are unchanged behaviourally. The student
gets a simple view-mode toggle; everything else stays as today.

This mirrors the existing sections/books feature almost exactly, so the plan is
"clone the sections pattern, add level ordering, and gate the student toggle on
data availability."

### Verification done against reality (not guessed)
- **Project actually inspected**: `tsfhrjipqukcutdkaiei` = **"Ahmed Mokhtar"** =
  the **mokhtar** flavour. All schema/RLS facts below were read from *that one
  project only*. The other two were **not** inspected (see Phase 6 drift pre-step).
- On mokhtar, **`books`** has exactly the 12 columns the repo models map; **no
  `level_id`/`level_order`**, **no `levels` table** exists yet. Repo and this live
  DB agree.
- **Live RLS confirmed (mokhtar)**: `sections_select_all` = `SELECT using (true)`;
  `sections_admin_write` = `ALL using is_admin() with check is_admin()`. Mirrored below.
- **Reorder precedent**: `public.reorder_lessons(jsonb)` (migration `0002_hardening.sql`),
  `language plpgsql security invoker`, loops `jsonb_array_elements`, relies on admin
  RLS. New reorder RPCs follow this.
- **Models** `SectionEntity`/`BookEntity` are plain `Equatable` (no freezed) → no
  `build_runner` needed for the new entities.
- **No caching** on the sections/books browse flow — queries hit Supabase directly.
  Device-local prefs only (`ThemeCubit` → `SharedPreferences` key `app_theme`); the
  view-mode choice follows that same pattern.
- **Migration number**: `0029` is the next free number (highest is `0028`). Confirmed.
- **UUID generator**: repo mixes `gen_random_uuid()` (newer feature tables) and
  `extensions.uuid_generate_v4()` (baseline incl. `sections`/`books`). `levels` is a
  sibling of `sections`, so it uses **`extensions.uuid_generate_v4()`** for parity.

### Project / doc facts
- `docs/PROJECT_STATE.md` does **not** exist (checked `git log --all` + all branches).
  Living state doc = **`docs/FEATURES.md`**.
- Live Supabase project → client mapping: **ahmed** = `Ahmed Abdel-Tawab`
  (`sbctifrsneiudphuqaqq`, created 2026-07-01, oldest), **medhat** = `Medhat-Abdelaziz`
  (`tnghjkbkiipdtdboqwkk`), **mokhtar** = `Ahmed Mokhtar` (`tsfhrjipqukcutdkaiei`,
  created 2026-11-05 — the one inspected). The MCP connection exposes only a subset at
  a time (and flips between them).
- **Rollout order**: Phase 1 applies to **medhat** only (after a read-only drift check vs
  the mokhtar snapshot). **ahmed goes last** in Phase 6 (oldest + largest client), together
  with **mokhtar**. Each project gets its own verify-query run.

---

## Final schema — `supabase/migrations/0029_levels.sql` (additive, idempotent)

Idempotent so it is safe to re-run across projects (`create ... if not exists`, `add
column if not exists`, `drop policy if exists`, `create or replace`). The canonical
file is `supabase/migrations/0029_levels.sql`; the authored version adds the
case-insensitive unique index `uq_levels_name` and column comments.

```sql
-- 1. levels — academic years/levels. Admin-managed, own display order.
create table if not exists public.levels (
  id         uuid primary key default extensions.uuid_generate_v4(),  -- sibling of sections
  name       text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- 2. books gains an optional single-level link + per-level ordering.
alter table public.books add column if not exists level_id uuid
  references public.levels(id) on delete set null;
alter table public.books add column if not exists level_order integer;

-- 3. Indexes. uq_levels_name = case-insensitive unique level name (trimmed);
--    blocks accidental duplicates. App maps violation 23505 → Arabic message.
create unique index if not exists uq_levels_name on public.levels (lower(btrim(name)));
create index if not exists idx_levels_sort  on public.levels(sort_order);
create index if not exists idx_books_level  on public.books(level_id, level_order);

-- 4. RLS — mirror sections exactly.
alter table public.levels enable row level security;
drop policy if exists "levels_select_all"  on public.levels;
create policy "levels_select_all"  on public.levels for select using (true);
drop policy if exists "levels_admin_write" on public.levels;
create policy "levels_admin_write" on public.levels
  using (public.is_admin()) with check (public.is_admin());

-- 5. Hard-delete hygiene: ON DELETE SET NULL clears books.level_id but leaves stale
--    books.level_order. Trigger nulls it so no orphan order remains.
create or replace function public.clear_book_level_order()
returns trigger language plpgsql security definer as $$
begin
  update public.books set level_order = null where level_id = OLD.id;
  return OLD;
end;
$$;
drop trigger if exists trg_levels_clear_book_order on public.levels;
create trigger trg_levels_clear_book_order
  before delete on public.levels
  for each row execute function public.clear_book_level_order();

-- 6. Transactional reorder RPCs (mirror reorder_lessons; security invoker, admin RLS applies).
create or replace function public.reorder_levels(p_updates jsonb)
returns void language plpgsql security invoker as $$
declare v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.levels set sort_order = (v_row->>'sort_order')::int
    where id = (v_row->>'id')::uuid;
  end loop;
end;
$$;
grant execute on function public.reorder_levels(jsonb) to authenticated;

-- reorder_level_books is SCOPED to one level: the `and level_id = p_level_id`
-- guard means a malformed/hostile payload can never reorder another level's books.
create or replace function public.reorder_level_books(p_level_id uuid, p_updates jsonb)
returns void language plpgsql security invoker as $$
declare v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.books set level_order = (v_row->>'level_order')::int
    where id = (v_row->>'id')::uuid
      and level_id = p_level_id;
  end loop;
end;
$$;
grant execute on function public.reorder_level_books(uuid, jsonb) to authenticated;
```

**`created_by` dropped** per the agreed spec — nothing writes it, so `levels` is
exactly `id, name, sort_order, created_at`.

**Junction-table migration path** (if "one level per book" is ever relaxed):
replace `books.level_id/level_order` with `book_levels(book_id, level_id,
level_order)`; backfill `insert into book_levels select id, level_id, level_order
from books where level_id is not null`; repoint queries.

---

## Files by layer

### Migration
- **`supabase/migrations/0029_levels.sql`** — new (above).
- **`docs/full_setup*.sql`** — append the same SQL so the fresh-install path stays in sync.

### Models (`lib/models/`)
- **`level_entity.dart`** — new. `LevelEntity {id, name, sortOrder, bookCount}`,
  plain `Equatable`, `fromJson(json, {int bookCount = 0})`. Clone of `SectionEntity`.
- **`book_entity.dart`** — modify. Add nullable `levelId`, `levelOrder` (read
  `level_id`/`level_order`, default `null`), add to `props`/`copyWith`. Backward
  compatible — existing `.select()` book queries now return these columns and
  `fromJson` tolerates absence.

### Repositories
- **`lib/features/levels/data/level_repository.dart`** — new (student).
  - `getLevels()` → **one** `levels` query ordered by `sort_order`, plus **one grouped
    aggregate** `select level_id, count(*) ... where status='published' and level_id
    is not null group by level_id` (NOT one count per level), joined in Dart. **Returns
    only levels whose published book count > 0** — empty levels are hidden from students.
  - `getBooksByLevel(id)` → books `where level_id=? and status='published' order by
    level_order`, reusing the progress-join from `SectionRepository.getBooksBySection`.
  - Connectivity precheck like every other repo.
- **`lib/features/admin/levels/data/admin_level_repository.dart`** — new (admin).
  `getLevels()` → **all** levels (incl. empty) with the same single grouped-count
  approach; `createLevel(name)` (next `sort_order` = max+1), `updateLevel(id,name)`
  — both catch the `uq_levels_name` unique violation (`PostgrestException` code
  `23505`) and return `ValidationFailure('اسم المستوى موجود بالفعل')`, never a raw
  Postgres error; `deleteLevel(id)` (hard delete), `reorderLevels(list)` → `reorder_levels` RPC,
  `getBooksInLevel(id)` (admin, all statuses, by `level_order`), `getAssignableBooks()`
  (all books left-joined to level name, by title, `.limit()`), `addBookToLevel(bookId,
  levelId)` (sets `level_id` + `level_order`=max+1; overwrite = MOVE),
  `removeBookFromLevel(bookId)` (nulls both), `reorderLevelBooks(levelId, list)` →
  `reorder_level_books(p_level_id, p_updates)` RPC.

### Blocs/State (4 explicit classes each, `Equatable`)
- Student: **`levels/cubit/levels_cubit.dart`** + state (`Initial/Loading/Loaded/Empty/Error`)
  — clone of `SectionsCubit`; **`levels/cubit/level_books_cubit.dart`** + state — clone of
  `SectionBooksCubit`.
- Admin: **`admin/levels/cubit/admin_levels_cubit.dart`** + state (load/create/update/
  delete/reorder + `MutationSuccess`) — clone of `AdminSectionsCubit`;
  **`admin/levels/cubit/admin_level_books_cubit.dart`** + state (load/add/remove/move/reorder).
- View-mode: **`lib/core/cubit/view_mode_cubit.dart`** — `ViewModeCubit extends
  Cubit<BrowseViewMode>` (`{sections, levels}`), `load()`/`set()` persisting
  `SharedPreferences` key `browse_view_mode`. Clone of `ThemeCubit`.

### Dashboard (admin) UI
- **`admin/levels/view/admin_levels_page.dart`** — new. `ReorderableListView` of levels
  (drag → `reorderLevels`), FAB add, edit/delete with confirm dialog ("حذف المستوى —
  سيتم إلغاء ربط الكتب به"). **Shows all levels incl. empty ones.** Clones
  `admin_sections_page.dart` + the loading-quotes reorder pattern.
- **`admin/levels/view/admin_level_form_page.dart`** — new. Single `name` field
  (create/edit). Clone of `admin_section_form_page.dart` minus the icon picker. On a
  duplicate name the cubit surfaces `ValidationFailure` as the Arabic SnackBar/field
  error "اسم المستوى موجود بالفعل" (from the `uq_levels_name` 23505 violation).
- **`admin/levels/view/admin_level_books_page.dart`** — new. `ReorderableListView` of the
  level's books by `level_order` (drag → `reorderLevelBooks`), per-row remove, "add book"
  → picker.
- **`admin/levels/view/admin_level_book_picker_page.dart`** — new. Lists assignable books;
  no-level books add directly; books already in another level show badge "في المستوى: X"
  and tapping offers a MOVE confirm → `addBookToLevel`.
- **`admin/dashboard/view/admin_dashboard_page.dart`** — modify. Add a "المستويات"
  `_QuickActionButton` → `context.push('/admin/levels')`.

### Student UI
- **`features/sections/view/sections_page.dart`** — modify. Add a `SegmentedButton`
  ("عرض بالأقسام" / "عرض بالمستويات") driven by `ViewModeCubit`. **Toggle flicker rule:**
  the toggle area reserves no space and shows nothing until the `LevelsCubit` availability
  check has resolved; it then either (a) renders the toggle (levels available) or (b) stays
  absent (none) — **no visible spinner for the toggle and no layout shift** when it turns
  out hidden. The sections grid renders immediately and independently; the toggle simply
  appears above it once availability is known. Body swaps between the sections grid and the
  new levels list based on the persisted mode (defaulting to sections while unresolved).
- **`features/levels/view/levels_list_view.dart`** — new widget. `ListView.builder` of
  levels by `sort_order` (name + book count), tap → `context.push('/levels/:id')`. Only
  non-empty levels reach here (repo filters them out).
- **`features/levels/view/level_books_page.dart`** — new. Clone of `section_books_page.dart`
  (book list + progress + search), fed by `LevelBooksCubit`.
- Book + lecture screens: **unchanged**.

### Router (`lib/app/router.dart`)
- Student: `/levels/:id` → `LevelBooksPage` + `LevelBooksCubit(LevelRepository)..loadBooks(id)`.
- Admin: `/admin/levels`, `/admin/levels/new`, `/admin/levels/:id/edit`,
  `/admin/levels/:id/books` (+ picker as a pushed page or bottom sheet).

### DI (`lib/app/bloc_providers.dart`)
- `RepositoryProvider<LevelRepository>`, `RepositoryProvider<AdminLevelRepository>`
  (both take `supabase, connectivity`).
- Global `BlocProvider<ViewModeCubit>` with `..load()` (next to `ThemeCubit`).

### Docs (Phase 6)
- **`docs/WHITELABEL.md`** — add levels to setup; bump the "Expected counts" table
  (tables 25→26, functions 26→29, triggers 17→18, policies 53→55, **indexes 55→59**
  — `pg_indexes` counts constraint-backed indexes, verified: `books_pkey` is listed,
  so the 4 new public indexes are `levels_pkey` + `uq_levels_name` + `idx_levels_sort`
  + `idx_books_level`; views unchanged) and the alphabetical table list.
- **`docs/FEATURES.md`** — document the browse-by-level feature (living state doc).
- **`docs/LEVELS_VIEW.md`** — this document.

---

## Workflow
- Branch **`feature/levels-view`** off `master`.
- Each phase is its **own commit**, pushed **after the code-reviewer pass** for that phase.

## Phases (each independently committable + testable)

1. **Migration + RLS + RPCs + medhat apply.** Author `0029_levels.sql`; create
   `docs/LEVELS_VIEW.md`; append to `full_setup*.sql`. **Drift check first** (read-only)
   on ahmed + medhat vs the mokhtar snapshot; stop if anything differs. If all agree, apply
   `0029` to **medhat only** (`tnghjkbkiipdtdboqwkk`), run the per-project verify query, then
   commit/push this phase. ahmed + mokhtar are deferred to Phase 6.
2. **Dashboard: levels CRUD + reorder.** `LevelEntity`, `AdminLevelRepository` (CRUD +
   `reorderLevels`), `AdminLevelsCubit`, `admin_levels_page` + form, dashboard tile, routes.
3. **Dashboard: assign books to a level + order within it.** Admin repo book methods,
   `AdminLevelBooksCubit`, `admin_level_books_page`, picker with MOVE.
4. **App data layer.** `BookEntity` level fields, `LevelRepository`
   (`getLevels`/`getBooksByLevel`, empty-level filtering, single grouped count), DI,
   `ViewModeCubit` + prefs. Unit tests for each repository method (success + every failure
   path, per CLAUDE.md), incl. a test that an empty level is excluded from `getLevels()`.
5. **App filter + browsing.** `ViewModeCubit` wiring, `sections_page` toggle (gated on
   availability, no flicker/layout-shift), `levels_list_view`, `level_books_page`,
   `/levels/:id` route.
6. **ahmed + mokhtar apply + docs.**
   - Re-run the drift check on ahmed and mokhtar (vs the mokhtar snapshot / medhat result)
     before applying; **report any drift and stop if found**.
   - Apply `0029_levels.sql` to **ahmed** (`sbctifrsneiudphuqaqq`), then to **mokhtar**
     (`tsfhrjipqukcutdkaiei`) once it is reachable again; run the per-project verify query
     on each.
   - Update `docs/WHITELABEL.md` + `docs/FEATURES.md`.

---

## Risks / edge cases
- **Existing book `.select()` queries** return the two new nullable columns
  automatically; `BookEntity.fromJson` defaults them to `null` (reads named keys) — safe.
- **Hard-delete orphan order**: `ON DELETE SET NULL` clears `level_id` but not
  `level_order` → handled by `trg_levels_clear_book_order`.
- **Cross-level reorder abuse**: prevented by the `p_level_id` guard in `reorder_level_books`.
- **Empty levels**: hidden from students (repo filters `bookCount > 0`), visible to admin.
- **`full_setup*.sql` drift**: WHITELABEL step 2 runs migrations individually OR
  `full_setup.sql`; both must get `0029`.
- **Doc count assertions** in WHITELABEL will be wrong until bumped (Phase 6).
- **Three projects may not be identical** — Phase 6 drift pre-step gates this.
- **Idempotency** — same file runs on three projects, possibly twice.
- **Toggle flicker** — handled by deferring the toggle until availability resolves, with
  no reserved space and no spinner.
- **Picker size**: `getAssignableBooks()` must `.order()` + `.limit()`.
- **Offline/RTL/i18n**: new repos do the connectivity precheck; new screens use
  `EdgeInsetsDirectional`/`SegmentedButton` (RTL-aware); Arabic strings tested with real
  voweled text; no freezed → no `build_runner`.
- **View-mode is device-local only** (`SharedPreferences`), never written to the DB.

---

## Verification
- `flutter analyze` clean; `dart format lib/`.
- Targeted tests only (repo test suite is partially broken project-wide): run
  `flutter test test/features/levels/` and touched files — not the full suite. Include a
  test asserting an empty level is excluded from student `getLevels()`.
- Run app as **admin** (ahmed flavor, both `--dart-define-from-file`): create/edit/reorder/
  delete levels; a level with no books still shows in the admin list; assign a book, move a
  book between levels, reorder within a level, remove a book.
- Run app as **student**: with no levels (or only empty ones) → no toggle, screen identical
  to today, no flicker/jump as the page loads; with ≥1 non-empty level → toggle switches to
  the levels list, **empty levels do not appear**, tapping a level lists its books by order,
  book/lecture screens unchanged; kill + relaunch → view-mode choice persisted.
- **Drift pre-step query** (run on ahmed + medhat, compare to mokhtar before applying):
  ```sql
  select
    (select array_agg(column_name order by ordinal_position)
       from information_schema.columns
       where table_schema='public' and table_name='books') as book_cols,
    (select array_agg(policyname order by policyname)
       from pg_policies where schemaname='public' and tablename='sections') as sections_policies,
    to_regclass('public.levels') is not null as levels_already_present;
  ```
- **Per-project verify query** (run on each after applying 0029):
  ```sql
  select to_regclass('public.levels') is not null as has_levels,
         (select count(*) from information_schema.columns
            where table_schema='public' and table_name='books'
              and column_name in ('level_id','level_order')) as book_cols, -- expect 2
         (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public'
              and p.proname in ('reorder_levels','reorder_level_books','clear_book_level_order')) as fns, -- expect 3
         (select count(*) from pg_indexes where schemaname='public'
            and indexname in ('uq_levels_name','idx_levels_sort','idx_books_level')) as new_idx; -- expect 3
  ```
- **Duplicate-name guard**: admin test — creating/editing a level to a name that already
  exists (case/whitespace-insensitive) shows "اسم المستوى موجود بالفعل", not a raw error.

---

## Open questions
- **Student levels list** — show the per-level book count (parity with the sections grid,
  my default) or name-only?
