// lib/features/achievements/widgets/stat_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;

  /// Raw integer value — rendered as Arabic-Indic numerals.
  final int value;
  final String label;

  /// Accent color for the icon and value number.
  /// Defaults to [AppColors.primary].
  final Color? color;

  String _toArabic(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;

    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            _toArabic(value),
            style: GoogleFonts.reemKufi(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
