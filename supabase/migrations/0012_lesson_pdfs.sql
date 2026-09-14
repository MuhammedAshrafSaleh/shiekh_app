-- ============================================================
-- Sheikhy — Migration 0012_lesson_pdfs.sql   (Multiple PDFs per lesson)
-- Additive only — runs on top of schema.sql + companion migrations.
-- Run ONCE in the Supabase SQL Editor.
--
-- Purpose: replace the single lessons.pdf_url with a proper child table so a
-- lesson can carry several titled PDFs (transcript, the book itself, handouts…).
-- Mirrors the existing lesson_quiz_questions pattern: a per-lesson child table
-- with its own RLS (students read published+entitled content, admin writes).
--
-- lessons.pdf_url is KEPT as a DEPRECATED compatibility shim for legacy app
-- builds. It is maintained solely by the trigger below (auto-mirror of the first
-- lesson_pdfs row). The app never writes it again.
--
-- ── Why NO unique(lesson_id, order_index) ──────────────────
-- The app reorders PDFs with one UPDATE per row via the Supabase client — each
-- is a separate transaction. A unique constraint (even DEFERRABLE INITIALLY
-- DEFERRED, which only defers to *that* transaction's commit) would collide
-- mid-sequence. Uniqueness is instead kept app-side by contiguous renumbering on
-- reorder (same approach as reorderLessons). A plain index is enough.
--
-- ── Why the mirror is a TRIGGER, not app code ──────────────
-- PDFs are saved via immediate per-row CRUD, not one atomic "save". Computing the
-- mirror in the Dart save handler would miss adds/deletes the admin never "saves"
-- and could leave pdf_url pointing at a deleted file. The trigger fires on every
-- insert/update/delete and stays correct (nulls out when the last PDF is gone).
-- SECURITY DEFINER lets the function UPDATE public.lessons even though the caller
-- (admin) has no direct grant path that RLS would otherwise satisfy; the WRITE
-- GATE stays the lesson_pdfs admin-write policy — a student is rejected there and
-- never reaches the trigger. search_path is pinned to '' (injection hardening);
-- every identifier inside the function is therefore fully qualified.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Child table (no unique constraint — plain index only)
-- ------------------------------------------------------------
create table if not exists public.lesson_pdfs (
  id          uuid primary key default uuid_generate_v4(),
  lesson_id   uuid not null references public.lessons(id) on delete cascade,
  title       text not null,
  url         text not null,
  order_index int  not null default 0,
  created_at  timestamptz not null default now()
);

comment on table public.lesson_pdfs is
  'ملفات PDF المتعددة لكل درس (النص، الكتاب، مرفقات). ترتيبها order_index.';

create index if not exists idx_lesson_pdfs_lesson
  on public.lesson_pdfs(lesson_id, order_index);

alter table public.lesson_pdfs enable row level security;

-- ------------------------------------------------------------
-- 1b. GRANTs — RLS is NOT a substitute for table privileges. Without these the
--     API roles get "permission denied for table lesson_pdfs" even though the
--     policies are correct. RLS then narrows these grants row-by-row.
-- ------------------------------------------------------------
grant select                 on public.lesson_pdfs to anon, authenticated;
grant insert, update, delete on public.lesson_pdfs to authenticated;

-- ------------------------------------------------------------
-- 2. RLS — mirror the lessons entitlement pattern.
--    SELECT: admin, or the parent lesson is published AND the caller is
--            entitled to it (can_read_lesson bypasses RLS internally → no
--            recursion, same mechanism as the lessons policy in 0007).
--    WRITE:  admin only (this is the security gate for the mirror trigger).
-- ------------------------------------------------------------
drop policy if exists "lesson_pdfs_select_entitled" on public.lesson_pdfs;
create policy "lesson_pdfs_select_entitled" on public.lesson_pdfs
for select using (
  public.is_admin()
  or exists (
    select 1 from public.lessons l
    where l.id = lesson_pdfs.lesson_id
      and l.status = 'published'
      and public.can_read_lesson(l.id, l.book_id)
  )
);

drop policy if exists "lesson_pdfs_admin_write" on public.lesson_pdfs;
create policy "lesson_pdfs_admin_write" on public.lesson_pdfs
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 3. Auto-mirror trigger: keep lessons.pdf_url = first lesson_pdfs row.
--    Runs AFTER every row change; nulls pdf_url when the last PDF is deleted.
--    SECURITY DEFINER (owner) so it can UPDATE public.lessons regardless of the
--    caller; the lesson_pdfs admin-write policy is the real gate.
--    search_path = '' → all identifiers below are fully qualified.
-- ------------------------------------------------------------
create or replace function public.sync_lesson_pdf_url()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Refresh the affected lesson(s). NEW/OLD lesson_id differ only if a PDF is
  -- ever re-parented; refresh both, skipping nulls and the duplicate.
  if (tg_op <> 'DELETE' and new.lesson_id is not null) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = new.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = new.lesson_id;
  end if;

  if (tg_op <> 'INSERT' and old.lesson_id is not null
      and old.lesson_id is distinct from
          (case when tg_op <> 'DELETE' then new.lesson_id end)) then
    update public.lessons
    set pdf_url = (
      select p.url from public.lesson_pdfs p
      where p.lesson_id = old.lesson_id
      order by p.order_index asc, p.id asc
      limit 1
    )
    where id = old.lesson_id;
  end if;

  return null; -- AFTER trigger: return value ignored
end;
$$;

drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
create trigger trg_sync_lesson_pdf_url
  after insert or update or delete on public.lesson_pdfs
  for each row execute function public.sync_lesson_pdf_url();

comment on column public.lessons.pdf_url is
  'DEPRECATED — auto-mirror of the first lesson_pdfs row (maintained by trigger '
  'sync_lesson_pdf_url), for legacy app builds only. Never written by the app.';

-- ------------------------------------------------------------
-- 4. Backfill: one PDF row per lesson that currently has a pdf_url.
--    (The trigger will re-affirm the same mirror value — harmless.)
-- ------------------------------------------------------------
insert into public.lesson_pdfs (lesson_id, title, url, order_index)
select id, 'ملف PDF', pdf_url, 0
from public.lessons
where pdf_url is not null
  and not exists (
    select 1 from public.lesson_pdfs p where p.lesson_id = public.lessons.id
  );

-- ============================================================
-- ROLLBACK:
-- ============================================================
/*
drop trigger if exists trg_sync_lesson_pdf_url on public.lesson_pdfs;
drop function if exists public.sync_lesson_pdf_url();
drop table if exists public.lesson_pdfs;   -- removes rows + policies
-- (lessons.pdf_url values remain as they were last mirrored)
*/

-- ============================================================
-- ✅ TEST HARNESS — run AFTER applying sections 1–4 above, as a SECOND query.
-- It is wrapped in a transaction that ROLLS BACK, so nothing persists.
-- Verifies:
--   (A) no 42P17 recursion when a real authenticated user selects lesson_pdfs;
--   (B) the SELECT policy hides other lessons' PDFs from a non-entitled user;
--   (C) SECURITY DEFINER lets the trigger update lessons.pdf_url, and the mirror
--       tracks insert / reorder / delete-last correctly;
--   (D) a NON-ADMIN authenticated user is REJECTED by the write policy and thus
--       can never fire the trigger (no privilege escalation via the mirror).
--
-- Replace <ADMIN_UUID>, <STUDENT_UUID>, <LESSON_UUID> (a published lesson) below.
-- Expected output: AAA → BBB → null, then 'OK: student insert rejected'.
-- ============================================================
/*
begin;

-- ---- (A)+(C) as ADMIN: writes allowed, trigger mirrors pdf_url --------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<ADMIN_UUID>","role":"authenticated","is_anonymous":false}';

-- insert two PDFs; after this, lessons.pdf_url should equal the order_index=0 url
insert into public.lesson_pdfs (lesson_id, title, url, order_index) values
  ('<LESSON_UUID>', 'الأول', 'https://drive.google.com/file/d/AAA/view', 0),
  ('<LESSON_UUID>', 'الثاني','https://drive.google.com/file/d/BBB/view', 1);
select pdf_url as after_insert_should_be_AAA
  from public.lessons where id = '<LESSON_UUID>';

-- reorder: make BBB first → mirror should become BBB
update public.lesson_pdfs set order_index = 0
  where lesson_id = '<LESSON_UUID>' and title = 'الثاني';
update public.lesson_pdfs set order_index = 1
  where lesson_id = '<LESSON_UUID>' and title = 'الأول';
select pdf_url as after_reorder_should_be_BBB
  from public.lessons where id = '<LESSON_UUID>';

-- delete all → mirror should become NULL
delete from public.lesson_pdfs where lesson_id = '<LESSON_UUID>';
select pdf_url as after_delete_should_be_null
  from public.lessons where id = '<LESSON_UUID>';

reset role;

-- ---- (D) as NON-ADMIN student: write MUST be rejected by RLS ----------------
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"<STUDENT_UUID>","role":"authenticated","is_anonymous":false}';

-- Expected: the insert raises insufficient_privilege → notice 'OK: ...'.
-- If the insert SUCCEEDS, the explicit SECURITY FAIL exception propagates and
-- aborts the block — it is NOT caught here. Do not widen this handler to
-- `others`: that would swallow the SECURITY FAIL and make the test unfailable.
do $$
begin
  insert into public.lesson_pdfs (lesson_id, title, url, order_index)
  values ('<LESSON_UUID>', 'اختراق', 'https://x', 0);
  raise exception 'SECURITY FAIL: student insert into lesson_pdfs succeeded';
exception
  when insufficient_privilege then
    raise notice 'OK: student insert rejected (%).', sqlerrm;
end $$;

-- (A)+(B) student SELECT must not raise 42P17 and only sees entitled rows:
select count(*) as visible_pdf_rows from public.lesson_pdfs;

reset role;
rollback;   -- nothing above is persisted
*/
-- ============================================================
-- End of migration 0012_lesson_pdfs.sql
-- ============================================================