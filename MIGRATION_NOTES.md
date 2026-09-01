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

## Also transitional

- `lib/core/theme/app_theme.dart` (`AppTheme.light/dark`) — the legacy Material
  theme still wired in `app/app.dart`. The heritage theme
  (`lib/core/theme/sheikhy_theme.dart` → `SheikhyTheme.light`) is currently used
  **only** by the theme-preview entrypoint. Global wiring happens once screens are
  migrated; at that point `AppTheme` is removed.
