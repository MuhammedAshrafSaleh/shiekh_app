# Sheikhy — White-Label Re-Deployment Guide

One deployment = one scholar. Follow these steps to create a new independent
instance of Sheikhy for a different sheikh / organisation.

---

## Prerequisites

- Flutter SDK ≥ 3.22 (`flutter doctor` clean)
- A new [Supabase](https://supabase.com) project (free tier is sufficient)
- Supabase CLI (`npm i -g supabase` or Homebrew) — needed for Edge Functions
- Firebase project with Cloud Messaging enabled (optional — required only for
  push notifications, Phase 5.4)
- Android Studio / Xcode for device signing

---

## Step 1 — New Supabase project

1. Create a project at <https://app.supabase.com>.
2. Note the **Project URL**, **anon key**, and **project ref** (Settings → API).

---

## Step 2 — Run the database schema

Open the Supabase **SQL Editor** and run files in this order:

1. `docs/schema.sql` — base 15-table schema + RLS policies + helper functions
2. Every file in `supabase/migrations/` in **ascending filename order**
   (alphabetical order = chronological order for this project).

The table below lists every migration as of today — but **always run whatever
files exist in the directory**; new migrations added after this writing will
appear with higher prefixes and must be included too.

### Migration reference (as of 2026-10-25 — run newer files too)

| File | What it does |
|---|---|
| `0001_app_support.sql` | Student-safe views (hide `correct_choice`, hide asker `user_id`) + `submit_final_exam` + `grade_lesson_quiz` RPCs |
| `0002_hardening.sql` | `reorder_lessons` RPC + featured-book count cap trigger |
| `0002_qa_fixes.sql` | Fix Q&A student view security + make `lesson_id` nullable on questions |
| `0002b_qa_fixes.sql` | Identical content to `0002_qa_fixes.sql`; idempotent — safe to run |
| `0003_student_questions_select_own.sql` | Add RLS policy so students can SELECT their own questions |
| `0004_onboarding.sql` | `onboarding_slides` table + generic Islamic seed slides (not sheikh-specific) |
| `0005_guest_mode.sql` | Guest-mode RLS: unauthenticated browsing of published content |
| `0006_lesson_entitlement.sql` | Lesson entitlement check (guest vs. enrolled student) |
| `0006_notification_scoping.sql` | Add `target_user_id` to notifications; scope personal notifications; updated `submit_final_exam` |
| `0006_test_harness.sql` | **SKIP — test only.** Wrapped in `BEGIN … ROLLBACK`; verifies 0006 only. |
| `0006b_notification_scoping.sql` | Two-line header stub, no SQL. Safe to run; no-op. |
| `0007_lesson_entitlement_fix.sql` | Fix lesson entitlement RLS for all claim variants |
| `0008_lesson_has_quiz_flag.sql` | `has_quiz` flag on the student-facing lessons view |
| `0009_split_media_position.sql` | Split `last_position_seconds` into separate video/audio resume columns |
| `0010_student_questions_admin_delete.sql` | Admin-only DELETE policy on `student_questions` |
| `0011_ai_question_generation.sql` | `generation_jobs` table + AI job status tracking infrastructure |
| `0011_test_harness.sql` | **SKIP — test only.** Wrapped in `BEGIN … ROLLBACK`; verifies 0011 only. |
| `0012_lesson_pdfs.sql` | Multiple PDF attachments per lesson (`lesson_pdfs` table) |
| `0013_lesson_notes.sql` | Student lecture notes per lesson |
| `0014_quiz_entitlement.sql` | Quiz entitlement for guest mode (stage 3) |
| `0015_lesson_duration.sql` | Admin-entered per-medium lesson durations + `get_study_seconds` RPC |
| `0016_lessons_public_duration.sql` | Expose duration columns in the student-facing `lessons_public` view |
| `0017_suggestions.sql` | `suggestions` table (home slider — مقترحات) + RLS + `media` bucket prefix |
| `0018_suggestion_notes.sql` | Timestamped notes on suggestion videos/audio |
| `0019_bank_lesson_summaries.sql` | Question-bank import drill-down: `ai_lesson_summary` column |
| `0020_practice_exams.sql` | Practice exams feature: `practice_attempts`, `loading_quotes` table + generic seed, `submit_practice_attempt` + `get_practice_eligible_lessons` RPCs |
| `0021_final_exam_source_fk_set_null.sql` | FK fix: deleting a quiz question that was imported into a final exam now sets the source ref to NULL instead of blocking the delete |
| `0022_app_secrets.sql` | `app_secrets` table (no client RLS) + `set_app_secret` / `clear_app_secret` / `get_secret_status` RPCs for admin-managed Gemini key |

### Ordering hazards

- **0002 collision:** Three files share the `0002` prefix
  (`0002_hardening`, `0002_qa_fixes`, `0002b_qa_fixes`). All are additive and
  idempotent. Run them in the alphabetical order shown; the `b` variant is a
  safe duplicate of the non-`b`.
- **0006 collision:** Four files share the `0006` prefix. Run
  `0006_lesson_entitlement.sql` and `0006_notification_scoping.sql` as
  migrations. **Skip `0006_test_harness.sql`** (it is a verification script
  that rolls back its own changes — running it as a migration will error if
  the required `public.users` rows don't exist). `0006b_notification_scoping.sql`
  is a two-line stub with no SQL; safe to run.
- **0020 / 0021 order:** On the live reference project, `0021` was applied
  before `0020` (out of filename order). Both migrations are fully independent
  and additive (`create table if not exists`, `create or replace`), so the
  order does not matter. A fresh deployment running them in filename order
  (`0020` → `0021`) is correct and produces the same schema.

### Post-schema verification

```sql
-- Three student-safe views must exist (created by 0001)
select viewname from pg_views
where schemaname = 'public'
  and viewname in (
    'lesson_quiz_questions_student',
    'final_exam_questions_student',
    'student_questions_public'
  );
-- Expected: 3 rows

-- Auth trigger must exist (created by schema.sql — never duplicate it)
select trigger_name from information_schema.triggers
where trigger_name = 'on_auth_user_created';
-- Expected: 1 row

-- app_secrets table must exist (created by 0022)
select tablename from pg_tables
where schemaname = 'public' and tablename = 'app_secrets';
-- Expected: 1 row

-- generation_jobs table must exist (created by 0011)
select tablename from pg_tables
where schemaname = 'public' and tablename = 'generation_jobs';
-- Expected: 1 row
```

---

## Step 3 — Supabase Auth settings

In the Supabase Dashboard → **Authentication → Settings**:

| Setting | Value |
|---|---|
| Email confirmations | **On** (recommended) |
| Minimum password length | 8 |
| Site URL | `io.sheikhy.app://` (or your custom scheme — must match the scheme in Step 7) |
| Redirect URLs | `io.sheikhy.app://reset-callback` (or `<your-scheme>://reset-callback`) |

---

## Step 4 — Storage bucket

In Supabase Dashboard → **Storage**:

1. Create a bucket named `media`.
2. Set it to **Public** (anonymous reads).
3. Add an RLS INSERT policy restricted to `is_admin()` (see `docs/schema.sql`
   for the helper function).
4. Banner images (`banners/` prefix) and suggestion images (`suggestions/`
   prefix) both live in this same `media` bucket — no extra bucket or
   per-prefix policy is needed.

---

## Step 5 — Configure `dart_define.json`

Copy the example file and fill in your values:

```bash
cp dart_define.example.json dart_define.json
```

```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>",
  "SHEIKH_NAME": "الشيخ فلان الفلاني",
  "PRIMARY_COLOR": "0xFF1B5E20"
}
```

- `PRIMARY_COLOR` is an ARGB hex integer. Dark green = `0xFF1B5E20`.
- `SHEIKH_NAME` defaults to `شيخي` if omitted; always set it explicitly.
- `dart_define.json` is gitignored — never commit it.
- **Optional sound overrides:** two sounds are brand-swappable via dart-define.
  If the sheikh records his own intro/success clips, add these keys:

  ```json
  "SPLASH_SOUND": "assets/sounds/splash.mp3",
  "SUCCESS_SOUND": "assets/sounds/success.mp3"
  ```

  The paths can point at any bundled asset file. The other six sounds
  (`tap`, `select`, `tick`, `tick_urgent`, `timeout`, `retry`) are shared
  and are not configurable via dart-define.

---

## Step 6 — Swap brand assets

| Asset | Actual path in repo | Notes |
|---|---|---|
| App icon source | `assets/app-icon.png` | 1024×1024 px, no alpha for iOS; used by `flutter_launcher_icons` |
| Sheikh photo | `assets/images/sheikh.png` | Displayed on home screen and profile. **Must be replaced** — this file currently contains the first sheikh's photo. |
| Splash sound | `assets/sounds/splash.mp3` | Plays on app launch. Replace or override via `SPLASH_SOUND` dart-define. |
| Success sound | `assets/sounds/success.mp3` | Plays on exam pass. Replace or override via `SUCCESS_SOUND` dart-define. |
| Shared SFX | `assets/sounds/{tap,select,tick,tick_urgent,timeout,retry}.{mp3,wav}` | Generic UI sounds — replace only if desired. |

`assets/images/.gitkeep` is a placeholder that keeps the directory in git.
After replacing `sheikh.png`, do not delete that file.

Run icon generation after replacing `app-icon.png`:

```bash
dart run flutter_launcher_icons
```

---

## Step 7 — App ID, bundle identifier, and app name

### Android — `android/app/build.gradle.kts`

The project uses **`build.gradle.kts`** (Kotlin DSL), not the older Groovy
`build.gradle`. Update two values:

| Key | Default | Action |
|---|---|---|
| `namespace` | `"io.sheikhy.app"` | Change to your new package name |
| `applicationId` (inside `defaultConfig`) | `"io.sheikhy.app"` | Change to the same new package name |

### Android — `android/app/src/main/AndroidManifest.xml`

`android:label` is **hardcoded** to the first sheikh's name and is
**not driven by dart-define**. Find this line and change it manually:

```xml
android:label="الشيخ أحمد بن عبد التواب"
```

### Deep-link scheme

The scheme `io.sheikhy.app://` appears in three places. If you change the
package name / scheme, update all three:

| File | What to change |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | `<data android:scheme="io.sheikhy.app"/>` intent-filter |
| `ios/Runner/Info.plist` | `CFBundleURLSchemes` → `io.sheikhy.app` |
| `lib/features/auth/data/auth_repository.dart` line 144 | `redirectTo: 'io.sheikhy.app://reset-callback'` — this is **hardcoded in Dart**, not configurable via dart-define; edit the string directly |

Also update the **Site URL** and **Redirect URL** in Supabase Auth settings
(Step 3) to match the new scheme.

### iOS — `ios/Runner.xcodeproj/project.pbxproj`

Change `PRODUCT_BUNDLE_IDENTIFIER` to your new bundle ID.

### Android release signing

The project reads signing configuration from `android/key.properties` (gitignored).
A template is provided at `android/key.properties.example`:

```
cp android/key.properties.example android/key.properties
# Then fill in the four values
```

- `storeFile` must be an **absolute path** to your `.jks` keystore stored
  **outside the repo**.
- If `key.properties` is absent, the release build falls back to debug keys
  (local testing only — Play Store will reject a debug-signed APK).
- Back up the keystore in a password manager; losing it means you can never
  ship an update to the same Play Store listing.

---

## Step 8 — Deploy Edge Functions

Two Edge Functions live under `supabase/functions/`:

| Function | Purpose |
|---|---|
| `generate-questions` | AI question generation from a lesson transcript |
| `transcribe-lesson` | AI audio transcription via Gemini Files API |

Deploy all functions to your new Supabase project:

```bash
supabase functions deploy generate-questions --project-ref <your-project-ref>
supabase functions deploy transcribe-lesson   --project-ref <your-project-ref>
```

Or to deploy all functions in the directory at once:

```bash
supabase functions deploy --project-ref <your-project-ref>
```

### Secrets the functions need

Both functions read `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` from Deno's environment. **Supabase injects all
three automatically** into every Edge Function at runtime — no manual
`supabase secrets set` is needed for these.

**The Gemini API key is not a Supabase secret.** It is stored in the
`public.app_secrets` database table (key = `gemini_api_key`, created by
migration `0022_app_secrets.sql`). The functions read it at call-time using
the service role, bypassing RLS. The admin sets it from within the app —
see Step 11.

### Timeout note

The Supabase Edge Function platform enforces a **150-second wall-clock
limit**. The functions apply an internal deadline of **100 seconds** for
the Gemini phase (giving ~50 s of margin). The Flutter client allows **180
seconds** before declaring a timeout (`timeout_http_client.dart`). Very long
audio files (> ~20 minutes) can still hit the platform limit; this is a known
limitation. Encourage the admin to keep individual lesson audio under 20
minutes, or split longer recordings.

---

## Step 9 — (Optional) Firebase push notifications

1. Create a Firebase project and add your Android/iOS app.
2. Download `google-services.json` → `android/app/`.
3. Download `GoogleService-Info.plist` → `ios/Runner/`.
4. Uncomment the `firebase_core` and `firebase_messaging` lines in
   `pubspec.yaml` and run `flutter pub get`.
5. Follow `docs/Supabase_Setup_Guide.md` §FCM for the Edge Function that
   triggers on notification insert.

---

## Step 10 — Build & run

```bash
# Debug
flutter run --dart-define-from-file=dart_define.json

# Release APK (requires android/key.properties with a real keystore)
flutter build apk --release --dart-define-from-file=dart_define.json

# Release IPA (requires Xcode signing configured)
flutter build ipa --release --dart-define-from-file=dart_define.json
```

---

## Step 11 — Promote the first admin (CC-29)

After the sheikh signs up through the app:

```sql
-- Run in Supabase SQL Editor (service-role context)
update public.users
set    is_admin = true
where  email = 'sheikh@example.com';
```

For the full admin-recovery runbook (lost access, compromised account, missing
profile row), see `docs/admin_recovery.sql`.

---

## Step 12 — Set the Gemini API key in-app

The AI features (`generate-questions` and `transcribe-lesson`) will return
`AI_KEY_MISSING` until the admin sets the key.

1. Log in as admin.
2. Go to **الإعدادات → مفتاح الذكاء الاصطناعي**.
3. Paste the Gemini API key and save.

The key is stored in `public.app_secrets` under the key `gemini_api_key`.
It is never exposed to the client — the admin screen only ever shows the
last four characters (masked status via `get_secret_status` RPC). The Edge
Functions read the raw value server-side using the service role.

There is **no environment-variable fallback** — AI generation will not work
until this step is completed.

---

## Client-identity audit — things that leak the first sheikh

Search the repo for these before sharing it with a second client:

| Location | Value that leaks first sheikh | How to fix |
|---|---|---|
| `dart_define.example.json` | `SHEIKH_NAME` set to first sheikh's name | Replace the value before sharing/committing the example |
| `android/app/src/main/AndroidManifest.xml` | `android:label="الشيخ أحمد بن عبد التواب"` | Edit manually — not driven by dart-define |
| `android/app/build.gradle.kts` | `applicationId = "io.sheikhy.app"`, `namespace = "io.sheikhy.app"` | Change to new package name |
| `ios/Runner/Info.plist` | `CFBundleURLSchemes` → `io.sheikhy.app` | Update to new scheme |
| `lib/features/auth/data/auth_repository.dart:144` | `'io.sheikhy.app://reset-callback'` hardcoded | Edit the string directly; no dart-define hook exists |
| `assets/images/sheikh.png` | First sheikh's photo | Replace with new sheikh's photo |
| `assets/app-icon.png` | App icon source (may contain first sheikh branding) | Replace before running `flutter_launcher_icons` |
| `android/key.properties.example` | Example keystore path uses `sheikhy-upload.jks` naming | Cosmetic; rename the example path to match new brand if desired |

The **onboarding slides** seed (`0004_onboarding.sql`) and **loading quotes**
seed (`0020_practice_exams.sql`) contain generic Islamic text (hadith,
Qur'anic verses) — they are not sheikh-specific and do not need to be changed.
The admin can edit both tables from the admin area after deployment.

---

## Checklist

- [ ] `docs/schema.sql` run without errors
- [ ] All `supabase/migrations/0*_*.sql` files run in ascending filename order
      (skip `*_test_harness.sql` files)
- [ ] Three student-safe views exist (`lesson_quiz_questions_student`,
      `final_exam_questions_student`, `student_questions_public`)
- [ ] `on_auth_user_created` trigger present (not duplicated)
- [ ] `app_secrets` table exists (migration 0022)
- [ ] `media` Storage bucket created and public
- [ ] `dart_define.json` filled in with new sheikh's name, colour, and
      Supabase credentials — not committed
- [ ] `assets/images/sheikh.png` replaced with new sheikh's photo
- [ ] `assets/app-icon.png` replaced; `dart run flutter_launcher_icons` run
- [ ] `android:label` in `AndroidManifest.xml` updated (not driven by dart-define)
- [ ] `applicationId` / `namespace` in `build.gradle.kts` updated
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` updated
- [ ] Deep-link scheme updated in manifest, Info.plist, and `auth_repository.dart:144`
      (and in Supabase Auth settings)
- [ ] `android/key.properties` created from the example with a real keystore
- [ ] Edge Functions deployed (`generate-questions`, `transcribe-lesson`)
- [ ] First admin promoted via SQL
- [ ] Gemini API key set in-app (الإعدادات → مفتاح الذكاء الاصطناعي)
- [ ] Smoke test: sign up → confirm email → log in → see home screen
- [ ] Smoke test: admin logs in → opens a lesson → AI generation returns questions

---

## What to automate next

These steps are the most error-prone and most worth scripting:

1. **Single `full_setup.sql`** — concatenate `schema.sql` and all
   `0*_*.sql` migration files (excluding test harnesses) in order into one
   idempotent script. A deployer could run a single file in the SQL Editor
   instead of 25+. The biggest risk is the duplicate `submit_final_exam`
   definitions across migrations; verify the final version is the one from
   `0006_notification_scoping.sql`.

2. **`new_client` shell script** — interactively prompts for sheikh name,
   primary colour, package name, and Supabase project ref; then patches
   `dart_define.json`, `AndroidManifest.xml` (`android:label`),
   `build.gradle.kts` (`applicationId`, `namespace`), `Info.plist`
   (scheme), and `auth_repository.dart` (redirect URL) in one pass.
   Prevents the silent identity-leak bugs listed in the audit table above.

3. **Flutter flavors** — replace the single `dart_define.json` pattern with
   proper Flutter flavors (`--flavor sheikh_a`, `--flavor sheikh_b`). Each
   flavor would have its own `dart_define.<flavor>.json` and its own
   `android:label` / bundle ID, eliminating the manual file-patching step
   entirely.

4. **`supabase db push` integration** — wire the migrations directory to the
   Supabase CLI's migration tracking (`supabase migration list`,
   `supabase db push`) so future migrations are applied with a single CLI
   command rather than manual copy-paste in the SQL Editor. Note: the `b`
   variants and test-harness files would need to be excluded or renamed to
   fit the CLI's sequential-integer naming convention.
