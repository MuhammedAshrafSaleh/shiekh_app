# Sheikhy — White-Label Re-Deployment Guide

One deployment = one scholar. Follow these steps to create a new independent
instance of Sheikhy for a different sheikh / organisation.

---

## Prerequisites

- Flutter SDK ≥ 3.22 (`flutter doctor` clean)
- A new [Supabase](https://supabase.com) project (free tier is sufficient)
- Firebase project with Cloud Messaging enabled (optional — required only for
  push notifications, Phase 5.4)
- Android Studio / Xcode for device signing

---

## Step 1 — New Supabase project

1. Create a project at <https://app.supabase.com>.
2. Note the **Project URL** and **anon key** (Settings → API).

---

## Step 2 — Run the database schema

Use the Supabase CLI (`supabase db push`) **or** open the SQL Editor and
run each migration file in ascending numeric order:

```
supabase/migrations/0000_baseline.sql      # enums, base tables, auth trigger, base RLS
supabase/migrations/0001_app_support.sql   # student-safe views + exam/quiz RPCs
supabase/migrations/0002_hardening.sql     # reorder_lessons RPC + featured-cap trigger
# …continue in order through the highest numbered file:
supabase/migrations/0024_storage.sql
```

`docs/schema.sql` is **superseded** by `0000_baseline.sql` and retained
for reference only — do not run it on a fresh project.

Verify after running all migrations:

```sql
-- Should return exactly three rows
select viewname from pg_views
where schemaname = 'public'
  and viewname in (
    'lesson_quiz_questions_student',
    'final_exam_questions_student',
    'student_questions_public'
  );

-- Trigger must exist (created by 0000_baseline.sql)
select trigger_name from information_schema.triggers
where trigger_name = 'on_auth_user_created';
```

---

## Step 3 — Supabase Auth settings

In the Supabase Dashboard → **Authentication → Settings**:

| Setting | Value |
|---|---|
| Email confirmations | **Off** |
| Minimum password length | 8 |
| Site URL | `<DEEP_LINK_SCHEME>://`  e.g. `io.sheikhy.medhat://` |
| Redirect URLs | `<DEEP_LINK_SCHEME>://reset-callback` |

> **Why "Confirm email: Off"?**  When email confirmation is enabled, the
> confirmation link redirects to the Supabase project's **Site URL**.  If
> Site URL is still the Supabase default (`http://localhost:3000`), the link
> goes to localhost and breaks signup for every new user.  Disabling
> confirmation eliminates this failure mode.  `<DEEP_LINK_SCHEME>` is the
> value from `client.json` (e.g. `io.sheikhy.medhat`) — use the **current
> client's own scheme**, never another client's.

---

## Step 4 — Storage bucket

The `media` bucket and its three admin-only RLS policies (INSERT / UPDATE /
DELETE) are **created automatically by `0024_storage.sql`**, which is included
in `full_setup.sql`.  No manual Supabase Dashboard steps are needed.

Banner and cover images live in the `media` bucket under `banners/` and
`books/` prefixes respectively; suggestion images use `suggestions/`.  All
write via the same three policies.  Verify after running migrations:

```sql
-- Expect 1 row: id='media', public=true
select id, name, public from storage.buckets;

-- Expect 3 rows (INSERT, UPDATE, DELETE)
select policyname, cmd from pg_policies
where schemaname = 'storage' and tablename = 'objects';
```

---

## Step 5 — Configure the client folder

Each sheikh is a **Flutter flavor** with its own folder under `clients/<name>/`.
See `docs/FLAVORS_PLAN.md` for the full flavor architecture. Create the folder:

`clients/<name>/client.json` (**committed** — non-secret):
```json
{
  "SHEIKH_NAME": "الشيخ فلان الفلاني",
  "PRIMARY_COLOR": "0xFF1B5E20",
  "DEEP_LINK_SCHEME": "io.sheikhy.<name>"
}
```

`clients/<name>/secrets.json` (**git-ignored** — never commit; template at
`clients/secrets.example.json`):
```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>"
}
```

`PRIMARY_COLOR` is an ARGB hex integer. Dark green = `0xFF1B5E20`.
`DEEP_LINK_SCHEME` must match the flavor's Android `deepLinkScheme`
manifestPlaceholder. The live client **ahmed** keeps `io.sheikhy.app`.

---

## Step 6 — Add brand assets

Place the client's assets in its folder (the single source of truth):

| Asset | Path | Notes |
|---|---|---|
| Launcher icon | `clients/<name>/icon.png` | 1024×1024 px, no alpha for iOS |
| Splash photo | `clients/<name>/sheikh.png` | sheikh photo shown on the runtime splash |

Stage them into the Flutter bundle (git-ignored generated copies), then
regenerate launcher icons:

```bash
tool/prepare_client.sh <name>
dart run flutter_launcher_icons
```

---

## Step 7 — Android flavor (App ID, label, scheme)

Add a `productFlavors` entry in `android/app/build.gradle.kts` (the shared
`namespace` stays `io.sheikhy.app`):

```kotlin
create("<name>") {
    dimension = "client"
    applicationId = "io.sheikhy.<name>"
    resValue("string", "app_name", "الشيخ فلان الفلاني")
    manifestPlaceholders["deepLinkScheme"] = "io.sheikhy.<name>"
}
```

The label (`@string/app_name`) and deep-link scheme (`${deepLinkScheme}`) are
read from the flavor — no manual manifest edits per client. The Dart-side
reset-password redirect comes from `DEEP_LINK_SCHEME` in `client.json`
(`AppConfig.deepLinkScheme`). iOS flavor/scheme setup is a later phase
(see `docs/FLAVORS_PLAN.md`).

> The live client **ahmed** keeps `io.sheikhy.app` everywhere so existing
> installs update in place — never change it.

---

## Step 8 — (Optional) Firebase push notifications

1. Create a Firebase project and add your Android/iOS app.
2. Download `google-services.json` → `android/app/`.
3. Download `GoogleService-Info.plist` → `ios/Runner/`.
4. Uncomment the `firebase_core` and `firebase_messaging` lines in
   `pubspec.yaml` and run `flutter pub get`.
5. Follow `docs/Supabase_Setup_Guide.md` §FCM for the Edge Function that
   triggers on notification insert.

---

## Step 9 — Build & run

Always name the flavor and pass both config files; stage brand assets first.

```bash
tool/prepare_client.sh <name>

# Debug
flutter run --flavor <name> \
  --dart-define-from-file=clients/<name>/client.json \
  --dart-define-from-file=clients/<name>/secrets.json

# Release APK
flutter build apk --release --flavor <name> \
  --dart-define-from-file=clients/<name>/client.json \
  --dart-define-from-file=clients/<name>/secrets.json
```

> There is no default flavor — plain `flutter run` (no `--flavor`) fails by
> design. iOS build commands come with the iOS phase.

---

## Step 10 — Promote the first admin (CC-29)

After the sheikh signs up through the app:

```sql
-- Run in Supabase SQL Editor (service-role context)
update public.users
set    role = 'admin'
where  email = 'sheikh@example.com';
```

For the full admin-recovery runbook (lost access, compromised account, missing
profile row), see `docs/admin_recovery.sql`.

---

## Step 11 — Set the AI (Gemini) API key

After deploying the `generate-questions` / `transcribe-lesson` Edge Functions,
open the app as admin → **الإعدادات ← مفتاح الذكاء الاصطناعي** and paste the
Gemini API key — otherwise AI question generation won't work (there is no env-var
fallback; the key is stored in the DB via `app_secrets`).

---

## Step 12 — AI job queue (background worker)

Transcription and question generation do **not** run inside the Edge Function
request — they are enqueued and processed by a background worker driven by
`pg_cron`. If you skip any step below, the app accepts the request, shows
**"في الطابور"**, and nothing ever picks it up — there is no error anywhere to
lead you to the cause. For *why* it is built this way, see `docs/AI_QUEUE.md`;
this section is only the per-project setup.

1. **Migrations.** `0025`–`0028` run with the rest in Step 2 (they are in the
   normal numbered sequence). `0025` also seeds a random `worker_secret` into
   `app_secrets` — never set it by hand.

2. **Deploy all three Edge Functions.** The worker must have JWT verification
   **off**; the CLI defaults it on, so pass `--no-verify-jwt`:

   ```bash
   supabase functions deploy transcribe-lesson   --project-ref <PROJECT_REF>
   supabase functions deploy generate-questions  --project-ref <PROJECT_REF>
   supabase functions deploy generation-worker   --project-ref <PROJECT_REF> --no-verify-jwt
   ```

   | Function | verify_jwt |
   |---|---|
   | `transcribe-lesson` | true |
   | `generate-questions` | true |
   | `generation-worker` | **false** |

   `generation-worker` is called by `pg_cron`, not a signed-in user, and
   authenticates with the `x-worker-secret` header. Deployed with JWT on, every
   cron call is rejected 401 and the queue silently does nothing.

3. **Confirm the extensions are installed** (migration `0026` enables them):

   ```sql
   select extname from pg_extension where extname in ('pg_cron', 'pg_net');
   -- expect two rows
   ```

4. **Create the cron schedule — once per project.** It embeds this client's
   project ref in the URL, so it cannot live in a migration. Replace
   `<PROJECT_REF>`:

   ```sql
   select cron.schedule(
     'generation-worker',
     '*/2 * * * *',
     $job$
     select net.http_post(
       url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/generation-worker',
       headers := jsonb_build_object(
                    'Content-Type',    'application/json',
                    'x-worker-secret', (select value from public.app_secrets where key = 'worker_secret')
                  ),
       body    := '{}'::jsonb,
       timeout_milliseconds := 150000
     )
     $job$
   );
   ```

5. **Verify the Realtime publication** (migration `0028` adds it). The admin
   status UI updates from these; without them the screen never refreshes on its
   own:

   ```sql
   select tablename from pg_publication_tables
    where pubname = 'supabase_realtime'
      and tablename in ('lessons', 'generation_jobs');
   -- expect both rows
   ```

6. **Smoke test.** Enqueue a transcription from the admin UI, then within
   ~2 minutes:

   ```sql
   select job_type, status, attempts, next_attempt_at, left(error_message, 120)
   from public.generation_jobs order by created_at desc limit 5;
   ```

   `attempts` must become **1 or more**. If it stays `0`, the cron is not
   reaching the worker — recheck the function name, the project ref in the
   schedule URL, and that `generation-worker` really has `verify_jwt` off.
   See `docs/AI_QUEUE.md` → "Diagnosing a stalled queue".

---

## Known Pitfalls

Silent failure modes that have caused issues on real deployments.

1. **"Automatically expose new tables" must be ON at project creation.**
   If this Supabase setting is OFF, PostgREST returns `42501: permission denied
   for schema public` on every table.  The grants block in `0000_baseline.sql`
   also covers this case, but leaving the setting ON avoids it entirely.

2. **Never use `DROP SCHEMA public CASCADE` to reset a project.**
   This destroys Supabase's internal default privileges and cannot be fully
   restored by migrations.  To start fresh, create a new Supabase project instead.

3. **Turn off "Confirm email" in Auth Settings.**
   If email confirmation is ON and the project's Site URL is still the Supabase
   default (`http://localhost:3000`), confirmation links go to localhost and every
   new signup breaks.  See Step 3.

4. **Never re-run individual migration files after running `full_setup.sql`.**
   `full_setup.sql` is a concatenation of every migration in order.  Re-running
   `0001_app_support.sql` (or any earlier file) after `full_setup.sql` downgrades
   functions to their pre-0005 versions.  If something went wrong mid-run, resume
   from the file that failed — do not re-run earlier ones from scratch.

---

## Checklist

- [ ] All migrations `0000_baseline.sql` → `0024_storage.sql` run without errors
- [ ] Three student-safe views exist (`lesson_quiz_questions_student`, etc.)
- [ ] `on_auth_user_created` trigger present (created by `0000_baseline.sql`)
- [ ] `media` Storage bucket + 3 policies created by migration `0024_storage.sql` (verify: 1 bucket, 3 storage policies)
- [ ] `clients/<name>/client.json` committed and `secrets.json` filled in (not committed)
- [ ] Brand assets added to `clients/<name>/` and staged via `tool/prepare_client.sh <name>`
- [ ] Android flavor added in `build.gradle.kts` (applicationId, app_name, deepLinkScheme)
- [ ] First admin promoted via SQL: `update public.users set role = 'admin' where email = 'sheikh@example.com';`
- [ ] Gemini API key set in-app (الإعدادات ← مفتاح الذكاء الاصطناعي)
- [ ] AI job queue (Step 12): 3 functions deployed (`generation-worker` at `verify_jwt: false`), `pg_cron`/`pg_net` installed, cron schedule created, `lessons`+`generation_jobs` in `supabase_realtime`, smoke test shows `attempts ≥ 1`
- [ ] Auth settings: "Confirm email" = **Off**, Site URL = `<DEEP_LINK_SCHEME>://`, Redirect URL = `<DEEP_LINK_SCHEME>://reset-callback`
- [ ] Smoke test: sign up → log in → see home screen

---

## Schema Verification

Run these queries in the Supabase SQL Editor after applying all migrations.
They are a quick sanity-check that every object was created successfully.

```sql
-- ── Tables (expect 25) ──────────────────────────────────────────────────────
select count(*) as table_count
from information_schema.tables
where table_schema = 'public'
  and table_type = 'BASE TABLE';

-- ── Views (expect 4) ────────────────────────────────────────────────────────
select count(*) as view_count
from information_schema.views
where table_schema = 'public';

-- ── Functions in public schema (expect 25) ──────────────────────────────────
select count(*) as function_count
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';

-- ── Triggers on public tables + auth schema (expect 11) ─────────────────────
--    9 on public tables + on_auth_user_created + on_auth_user_converted
select count(*) as trigger_count
from information_schema.triggers
where event_object_schema in ('public', 'auth');

-- ── RLS policies on public tables (expect ~55) ──────────────────────────────
select count(*) as policy_count
from pg_policies
where schemaname = 'public';

-- ── Indexes on public tables (expect ~35) ───────────────────────────────────
select count(*) as index_count
from pg_indexes
where schemaname = 'public';

-- ── Alphabetical table list (expect 25 rows) ────────────────────────────────
select tablename
from pg_tables
where schemaname = 'public'
order by tablename;
-- Expected tables:
-- app_secrets, books, certificates, enrollments, final_exam_attempts,
-- final_exam_questions, final_exam_settings, generation_jobs, home_banners,
-- lesson_notes, lesson_pdfs, lesson_progress, lesson_quiz_attempts,
-- lesson_quiz_questions, lessons, loading_quotes, notification_reads,
-- notifications, onboarding_slides, practice_attempts, sections,
-- student_questions, suggestion_notes, suggestions, users

-- ── Confirm is_admin() is SECURITY DEFINER (expect 1 row, prosecdef = true) ─
select proname, prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'is_admin';

-- ── Confirm on_auth_user_created trigger exists on auth.users ───────────────
select trigger_name, event_object_schema, event_object_table,
       action_timing, event_manipulation
from information_schema.triggers
where trigger_name = 'on_auth_user_created';
-- Expected: 1 row, event_object_schema = auth, event_object_table = users,
--           action_timing = AFTER, event_manipulation = INSERT

-- ── Storage buckets (expect 1) ──────────────────────────────────────────────
select id, name, public
from storage.buckets;
-- Expected: 1 row — id='media', name='media', public=true

-- ── Storage RLS policies on storage.objects (expect 3) ─────────────────────
select policyname, cmd
from pg_policies
where schemaname = 'storage'
  and tablename  = 'objects';
-- Expected: 3 rows:
--   'Admins can upload media'  INSERT
--   'Admins can update media'  UPDATE
--   'Admins can delete media'  DELETE

-- ── Schema grant sanity check (expect anon, authenticated, service_role) ────
select grantee, privilege_type
from information_schema.role_usage_grants
where object_schema = 'public'
order by grantee;
-- Expected: at least 3 rows — anon, authenticated, service_role — all USAGE
```

**Expected counts summary (fresh install after all 24 migrations):**

| Object | Count |
|---|---|
| Public tables | 25 |
| Public views | 4 |
| Public functions | 25 |
| Triggers (public + auth schema) | 11 |
| Public RLS policies | ~53 |
| Public indexes | ~35 |
| Storage buckets | 1 (`media`) |
| Storage RLS policies | 3 |
