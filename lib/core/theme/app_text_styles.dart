// lib/core/theme/app_text_styles.dart
//
// Heritage type scale. Source of truth: design/design_tokens.json (font.*).
//   display  → Aref Ruqaa  (ceremonial: book names, certificates)
//   h1–h3    → Reem Kufi   (headings + button labels)
//   body/…   → Tajawal     (all running text)
//
// Sizes/line-heights/weights are the token layer itself, so they are defined
// here (screens must never hardcode fontSize — they read these styles).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // Ceremonial display — Aref Ruqaa 56 / 1.18 / 700.
  static TextStyle get display => GoogleFonts.arefRuqaa(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: AppColors.ink,
      );

  // Smaller ceremonial display — Aref Ruqaa 36 / 1.3 / 700. Same calligraphic
  // treatment as [display] for titles that need less scale (e.g. onboarding
  // slide headings).
  static TextStyle get displaySm => GoogleFonts.arefRuqaa(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.ink,
      );

  // Headings — Reem Kufi.
  static TextStyle get h1 => GoogleFonts.reemKufi(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.ink,
      );

  static TextStyle get h2 => GoogleFonts.reemKufi(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: AppColors.ink,
      );

  static TextStyle get h3 => GoogleFonts.reemKufi(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.ink,
      );

  // Body — Tajawal, high line-height for long-form Arabic reading.
  static TextStyle get bodyLg => GoogleFonts.tajawal(
        fontSize: 19,
        fontWeight: FontWeight.w400,
        height: 1.85,
        color: AppColors.ink,
      );

  static TextStyle get body => GoogleFonts.tajawal(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.8,
        color: AppColors.ink,
      );

  static TextStyle get small => GoogleFonts.tajawal(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.7,
        color: AppColors.inkMuted,
      );

  static TextStyle get caption => GoogleFonts.tajawal(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.04 * 13, // tracking.caption 0.04em
        color: AppColors.inkMuted,
      );

  // Button label — Reem Kufi 17 / 500. Tight line-height (1.1): single-line
  // button labels must not inherit the tall body line box, which would push the
  // Arabic glyphs past a fixed control height.
  static TextStyle get buttonLabel => GoogleFonts.reemKufi(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.1,
      );

  // Brand / eyebrow label — Reem Kufi 15 / 500, wide tracking.
  static TextStyle get brandLabel => GoogleFonts.reemKufi(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.14 * 15, // tracking.brand 0.14em
        color: AppColors.goldLight,
      );

  /// Field label — Tajawal 14.5 / 500.
  static TextStyle get fieldLabel => GoogleFonts.tajawal(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );
}
