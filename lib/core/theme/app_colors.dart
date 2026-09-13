// lib/core/theme/app_colors.dart
//
// Heritage color roles for the Sheikhi redesign.
// Source of truth: design/design_tokens.json (color.*).
//
// White-labeling rule (DESIGN_SYSTEM.md §2):
//   - `primary` is NOT a fixed hex — it comes from AppConfig.primaryColor.
//   - primaryDeep / primarySoft / primaryTint are DERIVED from `primary`
//     programmatically via HSLColor, so any new sheikh color produces its
//     own coherent shade ramp automatically.
//   - gold / paper / ink / border / state colors are FIXED constants, shared
//     across every deployment to keep one heritage identity.
import 'package:flutter/material.dart';

import '../config/app_config.dart';

abstract final class AppColors {
  // ── Per-sheikh (variable) ──────────────────────────────────────────────
  /// The single white-label variable. token: primary.800 (#1E4034 default).
  static Color get primary => AppConfig.primaryColor;

  /// token: primary.900 (#14291F) — darker header/footer, button border.
  static Color get primaryDeep => _withLightnessFactor(primary, 0.62);

  /// token: primary.600 (#2F5F4C) — lighter accent, progress gradient end.
  static Color get primarySoft => _withLightnessFactor(primary, 1.5);

  /// token: primary.50 (#EAF0EC) — faint tinted background.
  static Color get primaryTint => _tint(primary);

  // ── Fixed heritage base (shared across all sheikhs) ────────────────────
  static const Color gold = Color(0xFFC09A4E); // gold.500
  static const Color goldLight = Color(0xFFE3CE9B); // gold.300
  static const Color goldDeep = Color(0xFF8A6A2F); // gold.600
  static const Color goldSoft = Color(0xFFF6EEDC); // gold.50

  static const Color paper = Color(0xFFFBF7EF); // paper.base — Scaffold bg
  static const Color paperSunk = Color(0xFFF1EADC); // paper.sunk — field bg
  static const Color surface = Color(0xFFFFFFFF); // paper.raised — card bg

  static const Color border = Color(0xFFE4D9C4); // border.base
  static const Color borderSubtle = Color(0xFFF1EADC); // border.subtle

  static const Color ink = Color(0xFF3B2E23); // ink.base — primary text
  static const Color inkMuted = Color(0xFF6B5B4B); // ink.muted
  static const Color inkFaint = Color(0xFFA2937F); // ink.faint — placeholder
  static const Color inkInvert = Color(0xFFFBF7EF); // ink.invert — on primary

  static const Color success = Color(0xFF2E6B4F); // state.success
  static const Color warning = Color(0xFF9A6B23); // state.warning
  static const Color danger = Color(0xFF8A3A2E); // state.danger
  static const Color info = Color(0xFF3D5A80); // state.info

  /// Pink-tinted background for field error state (from HTML reference).
  static const Color dangerBg = Color(0xFFFDF3F1);

  /// Soft blue background for the "صوتي" (audio) badge (from HTML reference).
  static const Color infoBg = Color(0xFFEAEFF6);

  // ── HSL derivation helpers ─────────────────────────────────────────────
  /// Scales lightness by [factor] (relative, so it works for any hue), keeping
  /// hue + saturation. factor < 1 darkens, > 1 lightens.
  static Color _withLightnessFactor(Color c, double factor) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
  }

  /// Very light, low-saturation tint of [c] for faint backgrounds.
  static Color _tint(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(0.93)
        .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
        .toColor();
  }
}
