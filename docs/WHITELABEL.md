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

Open the Supabase **SQL Editor** and run each file in order:

```
docs/schema.sql                        # base 15-table schema + RLS policies
supabase/migrations/0001_app_support.sql   # student-safe views + exam/quiz RPCs
supabase/migrations/0002_hardening.sql     # reorder_lessons RPC + featured-cap trigger
```

Verify after running `0001_app_support.sql`:

```sql
-- Should return exactly three rows
select viewname from pg_views
where schemaname = 'public'
  and viewname in (
    'lesson_quiz_questions_student',
    'final_exam_questions_student',
    'student_questions_public'
  );

-- Trigger must exist (created by schema.sql)
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

`PRIMARY_COLOR` is an ARGB hex integer. Dark green = `0xFF1B5E20`.
`dart_define.json` is gitignored — never commit it.

---

## Step 6 — Swap brand assets

| Asset | Path | Notes |
|---|---|---|
| App icon | `assets/images/logo.png` | 1024×1024 px, no alpha for iOS |
| Splash logo | `assets/images/splash_logo.png` | Used on the splash screen |
| Fonts | `assets/fonts/` | Cairo is bundled; replace if desired |

Run icon generation after replacing:

```bash
dart run flutter_launcher_icons
```

---

## Step 7 — App ID & bundle identifier

Update the package name in three places:

| File | Key |
|---|---|
| `android/app/build.gradle` | `applicationId` |
| `android/app/src/main/AndroidManifest.xml` | `package` |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` |

The deep-link scheme `io.sheikhy.app://` is referenced in
`android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` —
update both if you change the scheme.

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

```bash
# Debug
flutter run --dart-define-from-file=dart_define.json

# Release APK
flutter build apk --release --dart-define-from-file=dart_define.json

# Release IPA (requires Xcode signing configured)
flutter build ipa --release --dart-define-from-file=dart_define.json
```

---

## Step 10 — Promote the first admin (CC-29)

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

## Checklist

- [ ] `schema.sql` + both migrations run without errors
- [ ] Three student-safe views exist (`lesson_quiz_questions_student`, etc.)
- [ ] `on_auth_user_created` trigger present (not duplicated)
- [ ] `media` Storage bucket created and public
- [ ] `dart_define.json` filled in and not committed
- [ ] Brand assets replaced
- [ ] App ID / bundle identifier updated
- [ ] First admin promoted via SQL
- [ ] Auth email-confirm redirect URL set in Supabase Dashboard
- [ ] Smoke test: sign up → confirm email → log in → see home screen
