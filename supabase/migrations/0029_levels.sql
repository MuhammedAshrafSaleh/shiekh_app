-- ============================================================
-- Sheikhy — 0029_levels.sql
-- Browse-by-level feature. Additive only. Safe to re-run (idempotent).
-- Runs on top of the full 0000..0028 sequence.
-- ============================================================

-- ------------------------------------------------------------
-- 1. levels — academic years / levels. Admin-managed, own display order.
--    Sibling of public.sections → mirrors its uuid generator.
-- ------------------------------------------------------------
create table if not exists public.levels (
  id         uuid primary key default extensions.uuid_generate_v4(),
  name       text    not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
comment on table public.levels is 'المستويات الدراسية (السنوات) لتصفية الكتب حسب المستوى';

-- ------------------------------------------------------------
-- 2. books gains an optional single-level link + per-level ordering.
--    A book belongs to at most one level (or none).
-- ------------------------------------------------------------
alter table public.books add column if not exists level_id uuid
  references public.levels(id) on delete set null;
alter table public.books add column if not exists level_order integer;

comment on column public.books.level_id    is 'المستوى الدراسي المرتبط بالكتاب (اختياري، مستوى واحد كحد أقصى)';
comment on column public.books.level_order  is 'ترتيب الكتاب داخل المستوى';

-- ------------------------------------------------------------
-- 3. Indexes
--    uq_levels_name: case-insensitive unique level name (trimmed) — blocks
--    accidental duplicates. The app maps violation 23505 to an Arabic message.
-- ------------------------------------------------------------
create unique index if not exists uq_levels_name
  on public.levels (lower(btrim(name)));
create index if not exists idx_levels_sort
  on public.levels (sort_order);
create index if not exists idx_books_level
  on public.books (level_id, level_order);

-- ------------------------------------------------------------
-- 4. RLS — mirror sections exactly: readable by all, writable by admins only.
-- ------------------------------------------------------------
alter table public.levels enable row level security;

drop policy if exists "levels_select_all" on public.levels;
create policy "levels_select_all" on public.levels
  for select using (true);

drop policy if exists "levels_admin_write" on public.levels;
create policy "levels_admin_write" on public.levels
  using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 5. Hard-delete hygiene. ON DELETE SET NULL clears books.level_id but leaves
--    stale books.level_order; this trigger nulls it so no orphan order remains.
-- ------------------------------------------------------------
create or replace function public.clear_book_level_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.books set level_order = null where level_id = OLD.id;
  return OLD;
end;
$$;

drop trigger if exists trg_levels_clear_book_order on public.levels;
create trigger trg_levels_clear_book_order
  before delete on public.levels
  for each row
  execute function public.clear_book_level_order();

-- ------------------------------------------------------------
-- 6. Transactional reorder RPCs (mirror reorder_lessons; security invoker, so
--    the admin RLS UPDATE policy applies). Whole call rolls back on any failure.
-- ------------------------------------------------------------
create or replace function public.reorder_levels(p_updates jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.levels
    set    sort_order = (v_row->>'sort_order')::int
    where  id = (v_row->>'id')::uuid;
  end loop;
end;
$$;
grant execute on function public.reorder_levels(jsonb) to authenticated;

-- reorder_level_books is SCOPED to one level: the `and level_id = p_level_id`
-- guard means a malformed or hostile payload cannot reorder another level's books.
create or replace function public.reorder_level_books(p_level_id uuid, p_updates jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.books
    set    level_order = (v_row->>'level_order')::int
    where  id = (v_row->>'id')::uuid
      and  level_id = p_level_id;
  end loop;
end;
$$;
grant execute on function public.reorder_level_books(uuid, jsonb) to authenticated;
