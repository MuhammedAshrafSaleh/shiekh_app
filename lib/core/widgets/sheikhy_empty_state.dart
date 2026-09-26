// lib/core/widgets/sheikhy_empty_state.dart
//
// Heritage empty-state: icon in a rounded paperSunk box, Reem Kufi heading,
// Tajawal subtitle. Use for every screen with no data yet.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhyEmptyState extends StatelessWidget {
  const SheikhyEmptyState({
    super.key,
    required this.icon,
    required this.heading,
    required this.subtitle,
  });

  final IconData icon;
  final String heading;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.paperSunk,
                borderRadius: AppRadii.rLg,
              ),
              child: Icon(icon, size: 40, color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              heading,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
