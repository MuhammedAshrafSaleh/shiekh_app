// lib/core/widgets/sheikhy_progress_bar.dart
//
// Heritage progress bar (h10, sunk track, gradient fill). Spec: DESIGN_SYSTEM §5.
//
// NOTE: named `SheikhyProgressBar` (not `ProgressBar`) to avoid colliding with
// the legacy lib/core/widgets/progress_bar.dart — see MIGRATION_NOTES.md.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

enum SheikhyProgressVariant {
  primary, // in-progress: primary → primarySoft
  gold, // memorization / gold accent: gold → goldLight
}

class SheikhyProgressBar extends StatelessWidget {
  const SheikhyProgressBar({
    super.key,
    required this.value,
    this.variant = SheikhyProgressVariant.primary,
  });

  /// 0.0 – 1.0.
  final double value;
  final SheikhyProgressVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = variant == SheikhyProgressVariant.primary
        ? [AppColors.primary, AppColors.primarySoft]
        : [AppColors.gold, AppColors.goldLight];

    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rPill,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.rPill,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
