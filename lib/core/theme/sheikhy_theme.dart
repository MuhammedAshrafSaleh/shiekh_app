// lib/core/theme/sheikhy_theme.dart
//
// Assembles the heritage ThemeData from the token-backed theme classes.
//
// NOTE (DESIGN_SYSTEM.md §3 lists this as `app_theme.dart`): that filename is
// already taken by the legacy Material theme still used by un-migrated screens,
// so the heritage theme lives here as `SheikhyTheme`. During Step 0 it is used
// ONLY by the theme_preview entrypoint — it is intentionally NOT wired into
// app.dart yet (see MIGRATION_NOTES.md).
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';

abstract final class SheikhyTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.inkInvert,
          secondary: AppColors.gold,
          onSecondary: AppColors.ink,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          error: AppColors.danger,
          onError: AppColors.inkInvert,
          outline: AppColors.border,
        );

    final textTheme = TextTheme(
      displayLarge: AppTextStyles.display,
      headlineLarge: AppTextStyles.h1,
      headlineMedium: AppTextStyles.h2,
      headlineSmall: AppTextStyles.h3,
      titleLarge: AppTextStyles.h3,
      bodyLarge: AppTextStyles.bodyLg,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.small,
      labelLarge: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink),
      labelMedium: AppTextStyles.fieldLabel,
      labelSmall: AppTextStyles.caption,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.inkInvert),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.inkInvert,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3.copyWith(color: AppColors.inkInvert),
      ),
    );
  }
}
