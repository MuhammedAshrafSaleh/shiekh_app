// lib/core/widgets/sheikhy_notice.dart
//
// NEW (redesign — Auth Phase 1). Inline banner (icon + message) used as the
// design's top-of-form error/info strip (Login 1c, Create 2b, Reset 2c/2d).
// Variants: danger / info / success. Colors from AppColors state tokens.
// Spec: DESIGN_SYSTEM.md §7.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum SheikhyNoticeVariant { danger, info, success }

class SheikhyNotice extends StatelessWidget {
  const SheikhyNotice({
    super.key,
    required this.message,
    this.variant = SheikhyNoticeVariant.danger,
  });

  final String message;
  final SheikhyNoticeVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, IconData icon) = switch (variant) {
      SheikhyNoticeVariant.danger => (
          AppColors.danger,
          AppColors.dangerBg,
          Icons.error_outline,
        ),
      SheikhyNoticeVariant.info => (
          AppColors.info,
          AppColors.infoBg,
          Icons.info_outline,
        ),
      SheikhyNoticeVariant.success => (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.10),
          Icons.check_circle_outline,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: fg.withValues(alpha: 0.35),
          width: AppBorders.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: AppSpacing.s2 + 2),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.small.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
