// lib/core/theme/app_spacing.dart
//
// Heritage 4pt spacing scale. Source of truth: design/design_tokens.json (space.*).
//
// NOTE (transitional duplicate — see MIGRATION_NOTES.md): a legacy `AppSpacing`
// still lives in lib/core/constants/app_spacing.dart with a different scale.
// New (redesign) code imports THIS file. The legacy one is removed once no
// screen imports it.
abstract final class AppSpacing {
  static const double s1 = 4; // space-1
  static const double s2 = 8; // space-2
  static const double s3 = 12; // space-3
  static const double s4 = 16; // space-4
  static const double s5 = 24; // space-5
  static const double s6 = 32; // space-6
  static const double s7 = 48; // space-7
  static const double s8 = 64; // space-8
  static const double s9 = 96; // space-9

  /// Mobile page gutter (layout.gutter.mobile).
  static const double pageGutter = 24;
}
