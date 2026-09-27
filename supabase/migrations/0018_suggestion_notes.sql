-- ============================================================
-- Sheikhy — Migration 0018_suggestion_notes.sql   (Notes on suggestion videos)
-- Additive only — runs on top of schema.sql + 0001–0017.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: let a student attach a short plain-text note to a specific second of
-- a SUGGESTION video (the "مقترحات" home slider). Mirrors lesson_notes (0013)
-- but parents on suggestion_id instead of lesson_id/book_id. Strictly owner-only
-- (private notes). Deleting a suggestion cascades to its notes.
-- ============================================================

create table if not exists public.suggestion_notes (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users(id)       on delete cascade,
  suggestion_id    uuid not null references public.suggestions(id) on delete cascade,
  note_text        text not null check (char_length(btrim(note_text)) between 1 and 1000),
  position_seconds int  not null default 0 check (position_seconds >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.suggestion_notes is
  'ملحوظات الطالب النصية المرتبطة بلحظة زمنية في فيديو المقترحات.';

create index if not exists idx_suggestion_notes_user_suggestion
  on public.suggestion_notes(user_id, suggestion_id, position_seconds);

alter table public.suggestion_notes enable row level security;

-- Table privileges (RLS narrows these row-by-row).
grant select, insert, update, delete on public.suggestion_notes to authenticated;

-- RLS — strictly owner-only for every operation.
drop policy if exists "suggestion_notes_select_own" on public.suggestion_notes;
create policy "suggestion_notes_select_own" on public.suggestion_notes
  for select using (auth.uid() = user_id);

drop policy if exists "suggestion_notes_insert_own" on public.suggestion_notes;
create policy "suggestion_notes_insert_own" on public.suggestion_notes
  for insert with check (auth.uid() = user_id);

drop policy if exists "suggestion_notes_update_own" on public.suggestion_notes;
create policy "suggestion_notes_update_own" on public.suggestion_notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "suggestion_notes_delete_own" on public.suggestion_notes;
create policy "suggestion_notes_delete_own" on public.suggestion_notes
  for delete using (auth.uid() = user_id);

-- Auto-maintain updated_at (existing shared function, same as lesson_notes).
drop trigger if exists trg_suggestion_notes_updated_at on public.suggestion_notes;
create trigger trg_suggestion_notes_updated_at before update on public.suggestion_notes
  for each row execute function public.set_updated_at();

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop table if exists public.suggestion_notes;   -- removes rows, indexes, policies, trigger
*/
-- ============================================================
-- End of migration 0018_suggestion_notes.sql
-- ============================================================
