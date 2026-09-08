-- ============================================================
-- Sheikhy — Migration 0006_lesson_entitlement.sql  (Guest Mode, Stage 2)
-- Additive. Runs on top of 0005_guest_mode.sql.
--
-- ⚠️ INCIDENT NOTE (reconciled to live state):
-- The ORIGINAL version of this file ALSO replaced the lessons SELECT policy
-- with "lessons_select_entitled", whose USING clause contained a subquery over
-- public.lessons itself (min(order_index) per book). At query time that caused
-- "infinite recursion detected in policy for relation lessons" and broke the
-- app for ALL authenticated users. The policy was manually reverted in the SQL
-- Editor to the base policy:
--
--     create policy "lessons_select_published_or_admin" on public.lessons
--     for select using (public.is_admin() or status = 'published');
--
-- So this file now contains ONLY the part that is safely live: the URL-free
-- `lessons_public` metadata view. The (recursion-safe) entitlement enforcement
-- is deferred to 0007_lesson_entitlement_fix.sql — DO NOT re-add a lessons
-- self-reference to any policy on public.lessons.
--
-- LIVE STATE after this file + the manual revert:
--   • view public.lessons_public                    → present (created here)
--   • policy public.lessons.lessons_select_published_or_admin (base) → active
--   • content-leak protection (entitlement)          → NOT yet in effect
-- ============================================================

-- ------------------------------------------------------------
-- URL-free metadata view for the lesson LIST (readable by all).
-- security_invoker = false: runs as owner so it is unaffected by lessons RLS;
-- its SELECT list (no video_url / audio_url / pdf_url) is the boundary. The
-- has_* booleans expose only media *presence* for the list icons, never URLs.
-- ------------------------------------------------------------
create or replace view public.lessons_public
  with (security_invoker = false)
as
select
  id,
  book_id,
  order_index,
  title,
  description,
  audio_only,
  status,
  created_at,
  updated_at,
  (video_url is not null and not audio_only) as has_video,
  (audio_url is not null)                    as has_audio,
  (pdf_url is not null)                      as has_pdf
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;

-- ============================================================
-- End of migration 0006_lesson_entitlement.sql
-- ============================================================
