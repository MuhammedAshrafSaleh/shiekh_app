-- ============================================================
-- Sheikhy — Migration 0007_lesson_entitlement_fix.sql  (Guest Mode, Stage 2)
--
-- ✅ APPLIED 2026-09-08 — approved in writing after the TEST HARNESS (bottom of
--    this file) passed all three claim variants (guest / enrolled / unenrolled)
--    with no SQLSTATE 42P17. This IS the live lessons SELECT policy. The active
--    statements below (function + policy swap) are the migration; the harness at
--    the bottom stays commented, retained for the record.
--
-- Purpose: re-introduce lesson-content entitlement WITHOUT the recursion that
-- broke 0006. Closes the leak where any authenticated session (guest or
-- registered-not-enrolled) could read every lesson's video_url/audio_url/pdf_url
-- via the base `lessons` table.
--
-- ── Why 0006 recursed ──────────────────────────────────────
-- The 0006 policy USING clause contained:
--     order_index = (select min(l2.order_index) from public.lessons l2
--                    where l2.book_id = lessons.book_id and l2.status='published')
-- Evaluating that policy for a row of `lessons` runs a subquery that itself
-- reads `public.lessons`. RLS is enabled on lessons, so that inner read is
-- ALSO subject to the SAME policy, whose USING clause again reads lessons…
-- → unbounded self-application → Postgres aborts with SQLSTATE 42P17
-- "infinite recursion detected in policy for relation lessons".
-- (The enrollments EXISTS did NOT recurse — different table, no cycle.)
-- It only affected real users because the SQL Editor runs as the table OWNER,
-- which bypasses RLS — so the policy is never evaluated there. It fires only
-- for the `authenticated`/`anon` roles, i.e. actual app traffic.
--
-- ── The fix: move the lessons read into a SECURITY DEFINER function ──
-- A SECURITY DEFINER function owned by the table owner bypasses RLS on lessons
-- when it reads the table, so the policy no longer self-applies. This is the
-- SAME mechanism the existing public.is_admin() relies on (it reads public.users
-- from inside users' own policies without recursing). SECURITY DEFINER SQL
-- functions are also NOT inlined by the planner, so the subquery can't be
-- folded back into the policy expression.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Entitlement helper — reads lessons/enrollments with RLS bypassed.
-- ------------------------------------------------------------
create or replace function public.can_read_lesson(p_lesson_id uuid, p_book_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select
    -- the book's first published lesson is open to everyone (incl. guests)
    p_lesson_id = (
      select l.id
      from public.lessons l
      where l.book_id = p_book_id and l.status = 'published'
      order by l.order_index asc, l.id asc
      limit 1
    )
    -- or the caller is enrolled in the book (guests hold no enrollment rows)
    or exists (
      select 1 from public.enrollments e
      where e.book_id = p_book_id and e.user_id = auth.uid()
    );
$$;

revoke all on function public.can_read_lesson(uuid, uuid) from public;
grant execute on function public.can_read_lesson(uuid, uuid) to authenticated, anon;

-- ------------------------------------------------------------
-- 2. Swap the base lessons policy. The USING clause NO LONGER references
--    public.lessons directly — the only lessons read is inside the
--    SECURITY DEFINER function above (RLS-bypassed → no recursion).
-- ------------------------------------------------------------
drop policy if exists "lessons_select_published_or_admin" on public.lessons;
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_entitled" on public.lessons
for select using (
  public.is_admin()
  or (status = 'published' and public.can_read_lesson(id, book_id))
);

-- ============================================================
-- ROLLBACK (restore the currently-live base policy):
-- ============================================================
/*
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_published_or_admin" on public.lessons
  for select using (public.is_admin() or status = 'published');
drop function if exists public.can_read_lesson(uuid, uuid);
*/

-- ============================================================
-- ✅ TEST HARNESS — run this FIRST, verbatim, in the SQL Editor. It applies the
-- fix, exercises it AS a real authenticated user (which is what reproduces the
-- recursion — the editor's own postgres role bypasses RLS and would hide it),
-- then ROLLS BACK so nothing persists. If it completes without SQLSTATE 42P17,
-- the recursion is gone. EXPLAIN ANALYZE reports the per-row cost you asked for.
--
-- Replace <REAL_USER_UUID> with an existing public.users.id. To exercise each
-- branch, run the block three times varying the claims:
--   • guest:            "is_anonymous":true  (sees only first lessons)
--   • registered/enrolled: a uid that HAS enrollments (sees all their lessons)
--   • registered/none:  a uid with no enrollments (sees only first lessons)
-- ============================================================
/*
begin;

create or replace function public.can_read_lesson(p_lesson_id uuid, p_book_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_catalog as $fn$
  select p_lesson_id = (
      select l.id from public.lessons l
      where l.book_id = p_book_id and l.status = 'published'
      order by l.order_index asc, l.id asc limit 1)
    or exists (select 1 from public.enrollments e
               where e.book_id = p_book_id and e.user_id = auth.uid());
$fn$;
grant execute on function public.can_read_lesson(uuid, uuid) to authenticated, anon;

drop policy if exists "lessons_select_published_or_admin" on public.lessons;
drop policy if exists "lessons_select_entitled" on public.lessons;
create policy "lessons_select_entitled" on public.lessons
for select using (
  public.is_admin()
  or (status = 'published' and public.can_read_lesson(id, book_id))
);

-- Become a real end-user so RLS actually runs (this is the step 0006 needed):
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<REAL_USER_UUID>","role":"authenticated","is_anonymous":false}';

-- Must NOT raise "infinite recursion detected in policy for relation lessons":
explain analyze
select id, book_id, order_index
from public.lessons
where status = 'published'
limit 50;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0007_lesson_entitlement_fix.sql
-- ============================================================
