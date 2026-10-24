-- supabase/migrations/0022_app_secrets.sql
-- Admin-editable server secrets (additive-only).
--
-- Purpose: let the single admin rotate the Gemini API key in-app without the
-- developer touching Supabase secrets. The raw value is NEVER exposed to the
-- client: the table has RLS enabled with NO client-facing policy, so the
-- anon/admin JWT cannot read or write it. The value is read server-side only by
-- the Edge Functions (service role bypasses RLS). The client goes exclusively
-- through the SECURITY DEFINER RPCs below, which are admin-guarded and only ever
-- return a masked status — never the full key.

-- ------------------------------------------------------------
-- 1. app_secrets table (key/value, RLS on, no client policy)
-- ------------------------------------------------------------
create table if not exists public.app_secrets (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_secrets enable row level security;
-- Intentionally no policies: client (anon/authenticated) can neither read nor
-- write. Service role bypasses RLS for the Edge Functions; admins use the RPCs.

-- ------------------------------------------------------------
-- 2. set_app_secret(p_key, p_value) — admin upsert
-- ------------------------------------------------------------
create or replace function public.set_app_secret(p_key text, p_value text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_value is null or length(trim(p_value)) = 0 then
    raise exception 'empty value' using errcode = '22023';
  end if;

  insert into public.app_secrets (key, value, updated_at)
  values (p_key, trim(p_value), now())
  on conflict (key)
  do update set value = excluded.value, updated_at = now();
end;
$$;

-- ------------------------------------------------------------
-- 3. clear_app_secret(p_key) — admin delete
-- ------------------------------------------------------------
create or replace function public.clear_app_secret(p_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.app_secrets where key = p_key;
end;
$$;

-- ------------------------------------------------------------
-- 4. get_secret_status(p_key) — admin masked status
--    Returns { is_set, last4, updated_at }; never the full value.
-- ------------------------------------------------------------
create or replace function public.get_secret_status(p_key text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_value      text;
  v_updated_at timestamptz;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select value, updated_at into v_value, v_updated_at
  from public.app_secrets where key = p_key;

  if v_value is null then
    return json_build_object('is_set', false, 'last4', null, 'updated_at', null);
  end if;

  return json_build_object(
    'is_set', true,
    'last4', right(v_value, 4),
    'updated_at', v_updated_at
  );
end;
$$;

grant execute on function public.set_app_secret(text, text) to authenticated;
grant execute on function public.clear_app_secret(text) to authenticated;
grant execute on function public.get_secret_status(text) to authenticated;
