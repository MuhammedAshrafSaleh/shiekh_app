// lib/features/exam/widgets/timer_display.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_duration.dart';

class TimerDisplay extends StatelessWidget {
  final int secondsRemaining;

  const TimerDisplay({super.key, required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsRemaining <= 60;
    final formatted = formatMediaDuration(Duration(seconds: secondsRemaining));

    final bg = isUrgent
        ? AppColors.danger.withValues(alpha: 0.10)
        : AppColors.paperSunk;
    final borderColor = isUrgent
        ? AppColors.danger.withValues(alpha: 0.40)
        : AppColors.border;
    final iconColor = isUrgent ? AppColors.danger : AppColors.primary;
    final textColor = isUrgent ? AppColors.danger : AppColors.ink;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.rPill,
        border: Border.all(color: borderColor, width: AppBorders.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: iconColor),
          const SizedBox(width: AppSpacing.s1),
          Text(
            formatted,
            textDirection: TextDirection.ltr,
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
