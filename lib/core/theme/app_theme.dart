// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const Color gold = Color(0xFFFFB300);
  static const Color goldLight = Color(0xFFFFE082);
  static const Color progressGreen = Color(0xFF2E7D32);
  static const Color progressGold = Color(0xFFFFB300);
}

abstract final class AppTheme {
  static ThemeData light({required Color primaryColor}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      secondary: AppColors.gold,
    );
    return _buildTheme(scheme);
  }

  static ThemeData dark({required Color primaryColor}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: AppColors.gold,
    );
    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: GoogleFonts.cairoTextTheme(
        ThemeData(brightness: scheme.brightness).textTheme,
      ),
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: scheme.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimary);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
    );
  }
}
