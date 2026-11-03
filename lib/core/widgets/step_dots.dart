// lib/core/widgets/step_dots.dart
//
// Exam step indicator: equal segments — completed (primary), current (gold),
// upcoming (border). Spec: DESIGN_SYSTEM.md §5.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.total, required this.current})
    : assert(total > 0),
      assert(current >= 1);

  final int total;

  /// 1-based index of the current step.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s1 + 2),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: _colorFor(i),
                borderRadius: AppRadii.rPill,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _colorFor(int index) {
    final step = index + 1; // 1-based
    if (step < current) return AppColors.primary; // completed
    if (step == current) return AppColors.gold; // current
    return AppColors.border; // upcoming
  }
}
