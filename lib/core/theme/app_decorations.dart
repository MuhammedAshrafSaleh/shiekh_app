// lib/core/theme/app_decorations.dart
//
// Reusable BoxDecorations + shadows. Source: design/design_tokens.json
// (shadow.*, border.width.*) and the HTML reference for card/field styling.
import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_radii.dart';

abstract final class AppBorders {
  static const double hairline = 1;
  static const double control = 1.5;
  static const double accent = 4;
}

abstract final class AppShadows {
  // shadow.card — 0 2px 10px rgba(59,46,35,0.05). rgb(59,46,35) == ink.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  // shadow.raised — 0 6px 24px rgba(59,46,35,0.09).
  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.09),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];
}

abstract final class AppDecorations {
  /// Base card — white surface, hairline border, lg radius, soft shadow.
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.border, width: AppBorders.hairline),
        boxShadow: AppShadows.card,
      );

  /// Raised card — same, stronger shadow.
  static BoxDecoration get raised => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.border, width: AppBorders.hairline),
        boxShadow: AppShadows.raised,
      );

  /// Text field — sunk paper background, control-width border, md radius.
  static BoxDecoration get field => BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.border, width: AppBorders.control),
      );

  /// Focused field — white background, gold border.
  static BoxDecoration get fieldFocused => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.gold, width: AppBorders.control),
      );

  /// Error field — pink background, danger border.
  static BoxDecoration get fieldError => BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.danger, width: AppBorders.control),
      );
}
