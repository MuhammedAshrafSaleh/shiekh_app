-- supabase/migrations/0023_revoke_public_exec.sql
-- Harden app_secrets RPCs: revoke execute from public/anon before re-granting
-- to authenticated only.
--
-- Background: PostgreSQL grants EXECUTE to PUBLIC by default when a function
-- is created, so the anon role (unauthenticated Supabase clients) can invoke
-- these RPCs. The is_admin() guard inside each function prevents any actual
-- access to the key, but the connection is accepted and the function body runs
-- up to the guard check. Defense-in-depth: block the call at the grant level
-- so anon receives a 403 from PostgREST before the function even executes.
--
-- Idempotent: REVOKE of a non-held privilege is a no-op in PostgreSQL.
-- Safe to run on the live project — the existing authenticated grants remain
-- in effect; this only removes the implicit public/anon grant.

revoke execute on function public.set_app_secret(text, text) from public;
revoke execute on function public.set_app_secret(text, text) from anon;
grant  execute on function public.set_app_secret(text, text) to authenticated;

revoke execute on function public.clear_app_secret(text) from public;
revoke execute on function public.clear_app_secret(text) from anon;
grant  execute on function public.clear_app_secret(text) to authenticated;

revoke execute on function public.get_secret_status(text) from public;
revoke execute on function public.get_secret_status(text) from anon;
grant  execute on function public.get_secret_status(text) to authenticated;

-- ── Other SECURITY DEFINER functions in this repo with the same missing-revoke
--    pattern (grant to authenticated only, no revoke from public/anon).
--    NOT fixed here — listed for the next hardening migration.
--
--    Function                             Defined in
--    ─────────────────────────────────── ──────────────────────────────
--    reorder_lessons(jsonb)               0002_hardening.sql
--    grade_lesson_quiz(uuid, jsonb)       0005_guest_mode / 0014_quiz_entitlement
--    submit_final_exam(uuid,jsonb,tstz)   0005_guest_mode / 0006_notification_scoping
--    submit_lesson_quiz(uuid, jsonb)      0005_guest_mode / 0014_quiz_entitlement
--    get_lesson_quiz_review(uuid, int)    0005_guest_mode / 0014_quiz_entitlement
--    get_final_exam_review(uuid, uuid)    0005_guest_mode
--    get_my_study_seconds()               0015_lesson_duration
--    bank_lesson_summaries(uuid)          0019_bank_lesson_summaries
--
--    Intentionally excluded (anon access is correct by design):
--    is_guest()              — must be callable by anon (guest-mode detection)
--    can_read_lesson(uuid,uuid) — must be callable by anon (guest lesson access)
--
--    Trigger functions (enforce_featured_cap, sync_lesson_pdf_url,
--    handle_new_user, handle_anon_conversion, prune_practice_attempts) are
--    invoked by PostgreSQL triggers only, not via PostgREST RPC, so grant/
--    revoke on them has no client-facing effect.
