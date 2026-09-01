# MIGRATION_NOTES.md — redesign branch

Tracks the **deliberate, temporary duplicate symbols** introduced by the heritage
redesign (Step 0). The old (Material) and new (heritage) layers coexist while
screens are migrated one at a time. These duplicates must **not** silently become
permanent.

## Rule

1. As each legacy screen is redesigned, switch its imports from the legacy symbol
   to the heritage one.
2. When `flutter analyze` / `grep` shows **no file imports the legacy symbol
   anymore**, delete the legacy file **in that same PR**.
3. Every screen-migration PR updates the table below.
4. **No new code may import the legacy symbols.**
5. Migration is "done" only when this table is empty and all legacy files are gone
   (then delete this file).

## Open duplicates

| Symbol | Legacy (remove when unused) | Heritage (new — use this) | Status |
|---|---|---|---|
| `AppColors` | `lib/core/theme/app_theme.dart` | `lib/core/theme/app_colors.dart` | legacy still used by pre-redesign screens |
| `AppSpacing` | `lib/core/constants/app_spacing.dart` | `lib/core/theme/app_spacing.dart` | legacy still used by pre-redesign screens |
| `ProgressBar` → `SheikhyProgressBar` | `lib/core/widgets/progress_bar.dart` | `lib/core/widgets/sheikhy_progress_bar.dart` | legacy still used by pre-redesign screens |

## Migrated screens

| Screen | Legacy symbols dropped | Heritage symbols adopted |
|---|---|---|
| `signup_page.dart` | `AppSpacing` (constants), `PrimaryButton` | `AppColors`, `AppSpacing` (theme), `AppTextStyles`, `AppRadii`, all Sheikhy* widgets |
| `forgot_password_page.dart` | `AppSpacing` (constants), `PrimaryButton` | `AppColors`, `AppSpacing` (theme), `AppTextStyles`, all Sheikhy* widgets |
| `reset_sent_page.dart` | `AppSpacing` (constants), `PrimaryButton` | `AppColors`, `AppSpacing` (theme), `AppTextStyles`, `OrnamentDivider`, `SheikhyAuthHeader`, `SheikhyButton` |

## New heritage widgets (Auth Phase 1)

Added to `lib/core/widgets/` for the auth-screen migration. These are new
heritage components (not duplicates of a legacy symbol) — they compose the
existing theme tokens/decorations:

- `SheikhyAuthHeader` (`sheikhy_auth_header.dart`) — primary header band
  (arabesque + MihrabArch + title/subtitle + optional back link).
- `SheikhyPasswordField` (`sheikhy_password_field.dart`) — password field with
  a trailing eye-toggle. Exists because `SheikhyTextField` has only a
  `prefixIcon` (no suffix slot) and must not be modified; it reuses the same
  `AppDecorations.field*` tokens for an identical look.
- `SheikhyNotice` (`sheikhy_notice.dart`) — inline danger/info/success banner.
- `SheikhyCheckbox` (`sheikhy_checkbox.dart`) — heritage checkbox + label.
- `SheikhyPasswordStrength` (`sheikhy_password_strength.dart`) — segmented
  strength meter (presentational; derived from the field value).
- `SheikhyLabeledDivider` (`sheikhy_labeled_divider.dart`) — divider with a
  centered text label ("أو"), used on Login (1b) and Reset (2c). Distinct from
  `OrnamentDivider`, which centers a gold SVG motif rather than text.

## White-label assets

- `assets/images/sheikh.png` — the per-deployment sheikh photo shown on the
  Splash screen, declared via the `assets/images/` directory in `pubspec.yaml`.
  **Each sheikh deployment replaces this single file.** If it is absent, the
  splash falls back to the sheikh's initials (from `AppConfig.sheikhName`), so
  the build never breaks on a missing photo.

## Resolved — input decoration bleed

The legacy global `AppTheme` (still wired in `app/app.dart`) sets
`inputDecorationTheme(filled: true, fillColor: white)`, which used to bleed a
white block inside the cream heritage fields. **Fixed at source:**
`SheikhyTextField` and `SheikhyPasswordField` now set `filled: false` on their
`InputDecoration`, making them theme-independent. No per-screen wrapper needed.

## Also transitional

- `lib/core/theme/app_theme.dart` (`AppTheme.light/dark`) — the legacy Material
  theme still wired in `app/app.dart`. The heritage theme
  (`lib/core/theme/sheikhy_theme.dart` → `SheikhyTheme.light`) is currently used
  **only** by the theme-preview entrypoint. Global wiring happens once screens are
  migrated; at that point `AppTheme` is removed.
