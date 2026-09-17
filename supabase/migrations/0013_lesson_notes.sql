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

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop table if exists public.lesson_notes;   -- removes rows, indexes, policies, trigger
*/

-- ============================================================
-- TEST HARNESS — run AFTER applying the migration above, as a SECOND query.
-- Wrapped in a transaction that ROLLS BACK, so nothing persists.
-- Verifies (as the AUTHENTICATED role, not postgres):
--   (A) an authenticated user can insert + select their OWN note;
--   (B) a SECOND authenticated user CANNOT see the first user's note (owner-only).
--
-- Replace <USER_A_UUID> and <USER_B_UUID> (two distinct real users) and
-- <LESSON_UUID> / <BOOK_UUID> (a lesson and its book) below.
-- Expected: after_insert = 1, then user B sees 0, then 'OK: owner-only verified'.
-- ============================================================
/*
begin;

-- ---- (A) as USER A: insert + select own note --------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_A_UUID>","role":"authenticated","is_anonymous":false}';

insert into public.lesson_notes (user_id, lesson_id, book_id, note_text, position_seconds)
values ('<USER_A_UUID>', '<LESSON_UUID>', '<BOOK_UUID>', 'ملحوظة تجريبية', 125);

select count(*) as after_insert_should_be_1
  from public.lesson_notes where user_id = '<USER_A_UUID>';

reset role;

-- ---- (B) as USER B: must NOT see USER A's note ------------------------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<USER_B_UUID>","role":"authenticated","is_anonymous":false}';

do $$
declare v int;
begin
  select count(*) into v from public.lesson_notes;
  if v <> 0 then
    raise exception 'SECURITY FAIL: user B can see % note(s) that are not theirs', v;
  end if;
  raise notice 'OK: owner-only verified (user B sees 0 notes).';
end $$;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0013_lesson_notes.sql
-- ============================================================
