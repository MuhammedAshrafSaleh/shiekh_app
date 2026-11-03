// lib/core/widgets/sheikhy_badge.dart
//
// Pill status badges mapped to the state palette. Spec: DESIGN_SYSTEM.md §5.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum SheikhyBadgeVariant {
  isNew, // جديد
  passed, // مُجتاز
  certified, // مُجاز
  draft, // مسودة
  expired, // انتهت المدة
  audio, // صوتي
}

class SheikhyBadge extends StatelessWidget {
  const SheikhyBadge({super.key, required this.variant, this.label});

  final SheikhyBadgeVariant variant;

  /// Overrides the default Arabic word for the variant.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = _style(variant);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: AppRadii.rPill,
        border: s.border == null
            ? null
            : Border.all(color: s.border!, width: 1),
      ),
      child: Text(
        label ?? s.text,
        style: AppTextStyles.caption.copyWith(color: s.fg, letterSpacing: 0),
      ),
    );
  }

  _BadgeStyle _style(SheikhyBadgeVariant v) {
    switch (v) {
      case SheikhyBadgeVariant.isNew:
        return _BadgeStyle('جديد', AppColors.goldLight, AppColors.primaryDeep);
      case SheikhyBadgeVariant.passed:
        return _BadgeStyle('مُجتاز', AppColors.success, AppColors.inkInvert);
      case SheikhyBadgeVariant.certified:
        return _BadgeStyle(
          'مُجاز',
          AppColors.goldSoft,
          AppColors.goldDeep,
          border: AppColors.goldLight,
        );
      case SheikhyBadgeVariant.draft:
        return _BadgeStyle('مسودة', AppColors.paperSunk, AppColors.inkMuted);
      case SheikhyBadgeVariant.expired:
        return _BadgeStyle(
          'انتهت المدة',
          AppColors.danger,
          AppColors.inkInvert,
        );
      case SheikhyBadgeVariant.audio:
        return _BadgeStyle('صوتي', AppColors.infoBg, AppColors.info);
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle(this.text, this.bg, this.fg, {this.border});
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;
}
