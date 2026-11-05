-- ============================================================
-- Sheikhy — Migration 0024_storage.sql
-- Creates the `media` storage bucket and its admin-only write
-- policies idempotently.
--
-- Why this is needed:
--   Storage lives outside the PostgreSQL public schema and was
--   never part of the migration stack.  Every new client deployment
--   required a manual Supabase Dashboard step that was easy to miss,
--   leaving admin image upload broken with "new row violates
--   row-level security policy" on storage.objects.
--
--   Live (ahmed) has exactly three storage policies:
--     "Admins can upload media"  — INSERT
--     "Admins can update media"  — UPDATE
--     "Admins can delete media"  — DELETE
--   This migration reproduces them on every fresh project.
--
-- Public reads: The bucket is created as public=true, so any
--   client (anon or authenticated) can read objects by URL without
--   an RLS SELECT policy on storage.objects.  Only writes need
--   protecting.
--
-- Bucket used by the app: `media` only.
--   Verified by grepping storage.from() across lib/ — three files,
--   all using 'media':
--     lib/features/admin/banners/data/admin_banner_repository.dart
--     lib/features/admin/books/data/admin_book_repository.dart
--     lib/features/admin/suggestions/data/admin_suggestion_repository.dart
--
-- Idempotency: bucket INSERT uses ON CONFLICT DO NOTHING;
--   policies use DROP … IF EXISTS before CREATE.
--
-- Note on public.is_admin(): storage policies run in the storage
--   schema context, so the helper must be schema-qualified.
--
-- Additive only — runs on top of 0000_baseline.sql → 0023.
-- Run once in Supabase SQL Editor.
-- ============================================================

-- ── Create the bucket ────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

-- ── Remove existing policies if present (idempotency) ────────
drop policy if exists "Admins can upload media"  on storage.objects;
drop policy if exists "Admins can update media"  on storage.objects;
drop policy if exists "Admins can delete media"  on storage.objects;

-- ── Admin-only write policies ─────────────────────────────────

-- INSERT (upload new objects)
create policy "Admins can upload media"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'media'
    and public.is_admin()
  );

-- UPDATE (overwrite or rename existing objects)
create policy "Admins can update media"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'media'
    and public.is_admin()
  );

-- DELETE (remove objects)
create policy "Admins can delete media"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'media'
    and public.is_admin()
  );
