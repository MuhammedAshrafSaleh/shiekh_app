// lib/core/widgets/sheikhy_error_state.dart
//
// Heritage error-state: danger-bordered rounded box + warning icon, Reem Kufi
// heading, Tajawal message, optional technical detail, retry SheikhyButton.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sheikhy_button.dart';

class SheikhyErrorState extends StatelessWidget {
  const SheikhyErrorState({
    super.key,
    required this.heading,
    required this.message,
    required this.onRetry,
    this.technicalDetail,
  });

  final String heading;
  final String message;
  final VoidCallback onRetry;
  final String? technicalDetail;

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
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: AppRadii.rLg,
                border: Border.all(
                  color: AppColors.danger,
                  width: AppBorders.control,
                ),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(heading, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s3),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            if (technicalDetail != null) ...[
              const SizedBox(height: AppSpacing.s3),
              Text(
                technicalDetail!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkFaint,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s5),
            SheikhyButton.primary(
              label: 'إعادة المحاولة',
              onPressed: onRetry,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
