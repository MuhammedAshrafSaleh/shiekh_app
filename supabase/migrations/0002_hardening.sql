-- ============================================================
-- Sheikhy — Phase 8 Hardening Migration 0002_hardening.sql
-- Additive only — runs on top of 0001_app_support.sql.
-- Run once in Supabase SQL Editor.
-- ============================================================

-- ============================================================
-- CC-5: Transactional lesson reorder RPC
-- Wraps all order_index updates in a single transaction so a
-- network failure cannot leave order_index partially updated.
-- ============================================================

create or replace function public.reorder_lessons(
  p_updates jsonb  -- [{"id": "<uuid>", "order_index": <int>}, ...]
) returns void
language plpgsql
security invoker   -- admin RLS UPDATE policy already applies
as $$
declare
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(p_updates) loop
    update public.lessons
    set    order_index = (v_row->>'order_index')::int,
           updated_at  = now()
    where  id = (v_row->>'id')::uuid;
  end loop;
  -- If any row update fails the whole function call rolls back.
end;
$$;

-- Grant execute to authenticated users; RLS on the underlying table
-- already restricts non-admins from updating lessons.
grant execute on function public.reorder_lessons(jsonb) to authenticated;

-- ============================================================
-- CC-25: Featured-books cap — auto-drop lowest-priority book
-- When a 6th book is featured the one with the highest
-- featured_order (= lowest display priority) is automatically
-- unfeatured so the cap of 5 is never permanently exceeded.
-- ============================================================

create or replace function public.enforce_featured_cap()
returns trigger
language plpgsql
security definer
as $$
declare
  v_count int;
begin
  if NEW.is_featured = true then
    select count(*) into v_count
    from   public.books
    where  is_featured = true;

    if v_count > 5 then
      -- Unfeature the book with the highest featured_order (lowest priority)
      -- that is not the book just featured.
      update public.books
      set    is_featured    = false,
             featured_order = null
      where  id = (
        select id
        from   public.books
        where  is_featured = true
          and  id <> NEW.id
        order  by coalesce(featured_order, 2147483647) desc
        limit  1
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_featured_cap on public.books;
create trigger trg_featured_cap
  after insert or update of is_featured on public.books
  for each row
  execute function public.enforce_featured_cap();
