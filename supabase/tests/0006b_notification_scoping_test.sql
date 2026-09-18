-- ============================================================
-- Test harness for 0006b_notification_scoping.sql
-- Run AFTER applying 0006b, entirely in Supabase SQL Editor.
-- Everything is wrapped in BEGIN … ROLLBACK so the test rows
-- are never committed.
--
-- Requirements:
--   • At least 2 real (non-guest) rows in public.users.
--   • Migration 0006b already applied (target_user_id column
--     and "notifications_select_scoped" policy must exist).
-- ============================================================

begin;

do $$
declare
  v_user_a             uuid;
  v_user_b             uuid;
  v_notif_broadcast_id uuid := gen_random_uuid();
  v_notif_personal_id  uuid := gen_random_uuid();
  v_cnt                int;
begin

  -- ── Pick two real, non-guest users ─────────────────────────
  select id into v_user_a
  from public.users
  where email not like '%@guest.sheikhy.local'
  order by created_at
  limit 1;

  if v_user_a is null then
    raise exception
      'SETUP ERROR: no real users found in public.users. '
      'Sign up at least one student account before running this harness.';
  end if;

  select id into v_user_b
  from public.users
  where email not like '%@guest.sheikhy.local'
    and id <> v_user_a
  order by created_at
  limit 1;

  if v_user_b is null then
    raise exception
      'SETUP ERROR: need at least 2 real users in public.users. '
      'Sign up a second student account before running this harness.';
  end if;

  raise notice 'Using user_a: %', v_user_a;
  raise notice 'Using user_b: %', v_user_b;

  -- ── Seed test rows (running as postgres / table owner, bypasses RLS) ──
  insert into public.notifications (id, type, title, body, target_user_id) values
    (v_notif_broadcast_id, 'general',     'إشعار عام - اختبار 0006',        'يجب أن يراه جميع المستخدمين', null),
    (v_notif_personal_id,  'achievement', 'شهادة مستخدم A - اختبار 0006',  'يجب أن يراه مستخدم A فقط',    v_user_a);

  -- ── TEST 1: user_a sees both the broadcast and personal row ──
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',          v_user_a,
      'role',         'authenticated',
      'is_anonymous', false
    )::text,
    true   -- local to this transaction
  );
  set local role authenticated;

  select count(*) into v_cnt
  from public.notifications
  where id in (v_notif_broadcast_id, v_notif_personal_id);

  assert v_cnt = 2,
    format('TEST 1 FAIL: user_a should see 2 rows, got %s', v_cnt);
  raise notice 'TEST 1 PASS: user_a sees both broadcast and personal notification';

  -- ── TEST 2: user_b sees only the broadcast row ──────────────
  reset role;
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',          v_user_b,
      'role',         'authenticated',
      'is_anonymous', false
    )::text,
    true
  );
  set local role authenticated;

  select count(*) into v_cnt
  from public.notifications
  where id in (v_notif_broadcast_id, v_notif_personal_id);

  assert v_cnt = 1,
    format('TEST 2 FAIL: user_b should see 1 row (broadcast only), got %s', v_cnt);
  raise notice 'TEST 2 PASS: user_b sees only broadcast, NOT personal notification';

  -- ── TEST 3: user_b cannot see the personal row by direct id ─
  select count(*) into v_cnt
  from public.notifications
  where id = v_notif_personal_id;

  assert v_cnt = 0,
    format('TEST 3 FAIL: user_b must not see personal row directly, got %s', v_cnt);
  raise notice 'TEST 3 PASS: user_b gets zero rows when querying personal notification directly';

  reset role;
  raise notice '─────────────────────────────────────────';
  raise notice 'All 3 tests passed. Rolling back test data.';

end $$;

rollback;
-- ============================================================
-- End of 0006b_notification_scoping_test.sql
-- ============================================================
