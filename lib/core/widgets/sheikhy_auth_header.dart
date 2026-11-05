// lib/core/widgets/sheikhy_auth_header.dart
//
// NEW (redesign — Auth Phase 1). Heritage header band shared by the Login /
// Create / Reset screens: primary background + faint arabesque pattern +
// MihrabArch motif + title (Reem Kufi) + subtitle, with an optional top back
// link. Full-bleed (paints under the status bar) with a rounded bottom edge.
// Spec: DESIGN_SYSTEM.md §1/§5. RTL-safe (start/end, directional insets).
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'girih_background.dart';
import 'mihrab_arch.dart';

class SheikhyAuthHeader extends StatelessWidget {
  const SheikhyAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.backLabel = 'رجوع',
  });

  final String title;
  final String subtitle;

  /// When non-null, a top-start back link is shown ("‹ [backLabel]").
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.xl),
      ),
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        child: Stack(
          children: [
            // Faint arabesque — background only, never under the running text
            // (text sits centered above it with plenty of contrast).
            Positioned.fill(
              child: CustomPaint(
                painter: ArabesquePainter(
                  color: AppColors.goldLight,
                  opacity: 0.16,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: topInset + AppSpacing.s4,
                bottom: AppSpacing.s6,
                start: AppSpacing.pageGutter,
                end: AppSpacing.pageGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _BackLink(label: backLabel, onTap: onBack!),
                    ),
                  SizedBox(
                    height: onBack != null ? AppSpacing.s3 : AppSpacing.s2,
                  ),
                  const Center(child: MihrabArch(width: 46, height: 52)),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.inkInvert.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rSm,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.s1,
          horizontal: AppSpacing.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // RTL "back" points toward the start (right).
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.goldLight,
            ),
            const SizedBox(width: AppSpacing.s1),
            Text(
              label,
              style: AppTextStyles.small.copyWith(color: AppColors.goldLight),
            ),
          ],
        ),
      ),
    );
  }
}
