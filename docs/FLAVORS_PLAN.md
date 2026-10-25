# Multi-Client (White-Label) via Flutter Flavors

One codebase, one config folder per sheikh, built with Flutter **flavors**.
Every fix on `master` reaches all clients automatically. Android first; iOS is a
later phase (sketched at the end).

**Hard constraint:** the live client **Sheikh Ahmed** must keep applicationId
`io.sheikhy.app`, the same launcher label, the same deep-link scheme
`io.sheikhy.app://`, and the same signing behaviour, so existing installs update
in place.

---

## What is client-specific

| Item | Location | Notes |
|---|---|---|
| `applicationId` | `android/app/build.gradle.kts` (flavor) | per client; `namespace` stays shared `io.sheikhy.app` |
| launcher label | `AndroidManifest.xml` → `@string/app_name` (resValue per flavor) | per client |
| deep-link scheme (manifest) | `AndroidManifest.xml` → `${deepLinkScheme}` (manifestPlaceholder) | per client |
| deep-link redirect (Dart) | `lib/features/auth/data/auth_repository.dart` → `AppConfig.deepLinkScheme` | per client |
| launcher icon | `clients/<name>/icon.png` → staged to `assets/app-icon.png` → `flutter_launcher_icons` | per client |
| native splash color | `pubspec.yaml` `flutter_native_splash` | per client (parametrised in Phase 3) |
| runtime splash photo | `clients/<name>/sheikh.png` → staged to `assets/images/sheikh.png` (`splash_page.dart`) | per client |
| `SHEIKH_NAME`, `PRIMARY_COLOR`, `DEEP_LINK_SCHEME` | `clients/<name>/client.json` (committed) | per client |
| splash/success sounds | `AppConfig.splashSoundAsset` / `successSoundAsset` | per client (other SFX shared) |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `clients/<name>/secrets.json` (**git-ignored**) | per client, secret |
| onboarding slides, loading quotes | DB tables (admin-authored) | per Supabase project — not in code |
| Gemini AI key | DB `app_secrets` (admin UI) | per Supabase project — not in code |
| edge functions | `supabase/functions/*` | deployed per project |
| release keystore | `android/key.properties` (debug fallback); per-flavor `key.<name>.properties` later | per client |

---

## Folder layout

```
clients/
  secrets.example.json   # committed template
  ahmed/
    client.json          # COMMITTED  — SHEIKH_NAME, PRIMARY_COLOR, DEEP_LINK_SCHEME
    secrets.json         # GIT-IGNORED — SUPABASE_URL, SUPABASE_ANON_KEY
    icon.png             # launcher-icon source
    sheikh.png           # runtime splash photo
```

`clients/<name>/` is the **single source of truth** for brand assets.
`tool/prepare_client.sh <name>` copies them into the Flutter bundle locations:

```
clients/<name>/sheikh.png  ->  assets/images/sheikh.png   (git-ignored)
clients/<name>/icon.png    ->  assets/app-icon.png         (git-ignored)
```

Those two staged targets are **git-ignored generated outputs** — running the
prepare step for any client leaves `git status` clean. (Flutter asset bundling
is not flavor-aware, so staging is required for the runtime splash photo; the
launcher-icon source is staged so `flutter_launcher_icons` can read it.)

Committed vs secret config merge at build time via **two**
`--dart-define-from-file` flags (Flutter supports multiple).

`.gitignore` entries: `clients/*/secrets.json`, `assets/images/sheikh.png`,
`assets/app-icon.png`, `android/key.*.properties`, `android/app/*.jks`.

---

## Wiring

### Android flavors — `android/app/build.gradle.kts`
`namespace` stays shared. Each client is a flavor on the `client` dimension:
```kotlin
flavorDimensions += "client"
productFlavors {
    create("ahmed") {
        dimension = "client"
        applicationId = "io.sheikhy.app"              // live client — unchanged
        resValue("string", "app_name", "الشيخ أحمد بن عبد التواب")
        manifestPlaceholders["deepLinkScheme"] = "io.sheikhy.app"
    }
}
```

### Manifest — `android/app/src/main/AndroidManifest.xml`
- `android:label="@string/app_name"`
- deep-link `<data android:scheme="${deepLinkScheme}"/>`

### Dart — `lib/core/config/app_config.dart`
`AppConfig.deepLinkScheme` (env `DEEP_LINK_SCHEME`, default `io.sheikhy.app`).
`auth_repository.dart` builds `redirectTo: '${AppConfig.deepLinkScheme}://reset-callback'`.

### Icons & splash
Phase 2 keeps the existing `flutter_launcher_icons` / `flutter_native_splash`
`pubspec.yaml` blocks unchanged (reading the staged `assets/app-icon.png` and
the static splash color). Per-flavor icon/splash yamls
(`flutter_launcher_icons-<name>.yaml`, `flutter_native_splash-<name>.yaml`) are
introduced in Phase 3 when a second client's icon/color diverges.

---

## Signing (R1 deferred)

Phase 2 keeps today's behaviour: single `android/key.properties` with a debug
fallback — Sheikh Ahmed's signing is unchanged. Later, per-flavor keystores
(`android/key.<name>.properties`, git-ignored) select by flavor with the same
debug fallback.

**Why each client needs its own key:** Play Store identifies an app by
`applicationId` + signing key; updating a published app requires the same key
forever, and distinct clients are distinct listings, so separate keys isolate
them. Ahmed must keep its existing key to preserve in-place updates.

---

## Build & run

```bash
# Stage brand assets first (idempotent, leaves git clean)
tool/prepare_client.sh ahmed

# Debug
flutter run   --flavor ahmed \
  --dart-define-from-file=clients/ahmed/client.json \
  --dart-define-from-file=clients/ahmed/secrets.json

# Release APK
flutter build apk --release --flavor ahmed \
  --dart-define-from-file=clients/ahmed/client.json \
  --dart-define-from-file=clients/ahmed/secrets.json
```
VS Code: `.vscode/launch.json` has an `ahmed` config with a `prepare-ahmed`
pre-launch task (`.vscode/tasks.json`). Android Studio: a Run config per client
(Build flavor `ahmed`, the two `--dart-define-from-file` flags as additional
args, prepare script as an External Tool pre-launch step).

> There is no default flavor: plain `flutter run` without `--flavor` fails by
> design — every command/run-config names its flavor.

---

## Per-client manual checklist (future `new_client` automation)

Runtime/data steps, not compiled into the app (see `docs/WHITELABEL.md`):
1. New Supabase project → URL + anon key into `clients/<name>/secrets.json`.
2. Run `docs/full_setup.sql` (or the 4 `full_setup_part*.sql` parts) in order.
3. Create public `media` Storage bucket + `is_admin()` INSERT policy.
4. Deploy edge functions `generate-questions`, `transcribe-lesson`.
5. Supabase Auth Site URL + Redirect URL = `<scheme>://reset-callback`.
6. Promote first admin via SQL.
7. Enter Gemini key in admin UI.
8. Seed onboarding slides + loading quotes in admin UI.

---

## Phases

### Phase 2 — Ahmed as a flavor (zero behaviour change) ✅ this change
Files: `android/app/build.gradle.kts`, `AndroidManifest.xml`,
`lib/core/config/app_config.dart`, `lib/features/auth/data/auth_repository.dart`,
`clients/ahmed/*`, `clients/secrets.example.json`, `tool/prepare_client.sh`,
`.vscode/{launch,tasks}.json`, `.gitignore`, docs.
Verify: build ahmed APK; `aapt` confirms `package=io.sheikhy.app`,
label `الشيخ أحمد بن عبد التواب`, scheme `io.sheikhy.app`; icon/splash match
today's build; `flutter analyze` clean; install over existing install updates in
place.

### Phase 3 — Add Medhat
New gradle flavor + `clients/medhat/*` + per-flavor icon/splash yamls + run
config. **Medhat's name and color are provided by the owner — not invented.**
Test: build both flavors; install Ahmed + Medhat side-by-side (distinct
applicationIds coexist); each points at its own Supabase + branding.

### Phase 4 — `new_client` script
`tool/new_client.sh <name>` scaffolds `clients/<name>/`, appends the gradle
flavor + icon/splash yamls, and prints the manual Supabase checklist above.

### iOS (later phase — sketch only)
Per-client **scheme**/configuration with `.xcconfig` files, per-scheme
`PRODUCT_BUNDLE_IDENTIFIER`, `CFBundleURLSchemes` in `Info.plist`, per-scheme
app icon sets and launch assets, and a matching signing/provisioning profile per
bundle id. Planned in detail when iOS work starts.
