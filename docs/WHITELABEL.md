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
supabase/migrations/0023_revoke_public_exec.sql
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
| Email confirmations | **On** (recommended) |
| Minimum password length | 8 |
| Site URL | `io.sheikhy.app://` (or your custom scheme) |
| Redirect URLs | `io.sheikhy.app://reset-callback` |

---

## Step 4 — Storage bucket

In Supabase Dashboard → **Storage**:

1. Create a bucket named `media`.
2. Set it to **Public** (anonymous reads).
3. Add an RLS INSERT policy restricted to `is_admin()` (see `docs/schema.sql`
   for the helper function).
4. Banner and suggestion images both live in this same `media` bucket —
   under the `banners/` and `suggestions/` prefixes respectively. No extra
   bucket or per-prefix policy is needed.

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

## Checklist

- [ ] All migrations `0000_baseline.sql` → `0023_revoke_public_exec.sql` run without errors
- [ ] Three student-safe views exist (`lesson_quiz_questions_student`, etc.)
- [ ] `on_auth_user_created` trigger present (created by `0000_baseline.sql`)
- [ ] `media` Storage bucket created and public
- [ ] `clients/<name>/client.json` committed and `secrets.json` filled in (not committed)
- [ ] Brand assets added to `clients/<name>/` and staged via `tool/prepare_client.sh <name>`
- [ ] Android flavor added in `build.gradle.kts` (applicationId, app_name, deepLinkScheme)
- [ ] First admin promoted via SQL: `update public.users set role = 'admin' where email = 'sheikh@example.com';`
- [ ] Gemini API key set in-app (الإعدادات ← مفتاح الذكاء الاصطناعي)
- [ ] Auth email-confirm redirect URL set in Supabase Dashboard
- [ ] Smoke test: sign up → confirm email → log in → see home screen

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
```
