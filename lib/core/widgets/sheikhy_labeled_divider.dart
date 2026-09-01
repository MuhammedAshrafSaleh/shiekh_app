// lib/core/widgets/sheikhy_labeled_divider.dart
//
// NEW (redesign — Auth Phase 1). A horizontal divider with a centered label
// (e.g. "أو") — used between the primary CTA and the alternate action on
// Login (1b) and Reset (2c). Distinct from OrnamentDivider, which centers a
// gold SVG motif rather than text. Lines fade toward the center.
// Spec: design/screens/auth/1b, 2c. RTL-safe.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhyLabeledDivider extends StatelessWidget {
  const SheikhyLabeledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _FadeLine(fadeToEnd: false)),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s3,
          ),
          child: Text(
            label,
            style: AppTextStyles.small.copyWith(color: AppColors.inkFaint),
          ),
        ),
        const Expanded(child: _FadeLine(fadeToEnd: true)),
      ],
    );
  }
}

class _FadeLine extends StatelessWidget {
  const _FadeLine({required this.fadeToEnd});

  /// When true the line fades out toward the end (used on the trailing side).
  final bool fadeToEnd;

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.border, AppColors.border.withValues(alpha: 0)];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: fadeToEnd ? colors.reversed.toList() : colors,
        ),
      ),
    );
  }
}
