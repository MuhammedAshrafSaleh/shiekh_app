-- ============================================================
-- Sheikhy — Admin Account Recovery (CC-29)
-- Run in the Supabase SQL Editor (service_role context).
-- Use this script when the sole admin account is inaccessible.
-- ============================================================

-- STEP 1 ── Verify the current admin users ──────────────────
-- Lists every user that has is_admin = true in public.users.
select u.id,
       u.full_name,
       u.email,
       u.is_admin,
       u.created_at
from   public.users u
where  u.is_admin = true
order  by u.created_at;

-- STEP 2 ── Promote an existing user to admin ───────────────
-- Replace <USER_UUID> with the UUID from auth.users.
-- Run STEP 1 first to confirm the user's profile row exists.
/*
update public.users
set    is_admin = true
where  id = '<USER_UUID>';
*/

-- STEP 3 ── If the profile row is missing (trigger may have failed)
-- Insert the profile row manually before promoting.
/*
insert into public.users (id, full_name, email, is_admin)
select id,
       raw_user_meta_data->>'full_name',
       email,
       true
from   auth.users
where  id = '<USER_UUID>'
on conflict (id) do update
  set is_admin = true;
*/

-- STEP 4 ── Demote a compromised admin account ──────────────
/*
update public.users
set    is_admin = false
where  id = '<COMPROMISED_USER_UUID>';
*/

-- STEP 5 ── Force a password reset via Supabase Dashboard ───
-- 1. Open Supabase Dashboard → Authentication → Users.
-- 2. Click the admin user → "Send password reset email".
-- 3. Alternatively use the service-role API:
--      POST /auth/v1/admin/users/<USER_UUID>
--      { "password": "<new_temp_password>" }
-- Then ask the user to change it immediately after first login.

-- STEP 6 ── Verify final state ──────────────────────────────
select u.id, u.full_name, u.email, u.is_admin
from   public.users u
where  u.is_admin = true;
