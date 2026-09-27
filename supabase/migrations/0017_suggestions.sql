-- ============================================================
-- Sheikhy — Companion Migration 0017_suggestions.sql
-- Additive only — runs on top of the base schema.sql + 0001–0016.
-- Run this ONCE in Supabase SQL Editor.
-- Adds the admin-managed "مقترحات" (suggestions) home slider: curated
-- video (YouTube) / audio (Google Drive) media cards shown to students.
-- RLS mirrors onboarding_slides (0004): public reads active rows, admin full CRUD.
-- Images reuse the existing `media` storage bucket under a `suggestions/` prefix
-- (same convention banners use with `banners/`) — no new bucket needed.
-- ============================================================

create table public.suggestions (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  image_url        text not null,
  content_type     text not null check (content_type in ('video', 'audio')),
  content_url      text not null,
  duration_seconds int  not null check (duration_seconds > 0),
  sort_order       int,            -- nullable: query sorts NULLs LAST (nullsFirst: false)
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Student fetch orders by (is_active, sort_order); admin list scans all rows.
create index idx_suggestions_active_order
  on public.suggestions (is_active, sort_order);

alter table public.suggestions enable row level security;

-- Anyone can read active suggestions; admin can read all (incl. inactive).
create policy "suggestions_read_active_or_admin" on public.suggestions
  for select using (is_active = true or public.is_admin());

-- Only admin can insert/update/delete.
create policy "suggestions_admin_write" on public.suggestions
  for all using (public.is_admin());

-- Keep updated_at fresh on every update.
create or replace function public.set_suggestions_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_suggestions_updated_at
  before update on public.suggestions
  for each row execute function public.set_suggestions_updated_at();
