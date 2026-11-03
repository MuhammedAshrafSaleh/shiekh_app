// lib/features/books/widgets/final_exam_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/final_exam_attempt_entity.dart';

class FinalExamCard extends StatelessWidget {
  final bool isEnrolled;
  final bool isExamPublished;
  final double completionPercentage;
  final FinalExamAttemptEntity? bestAttempt;
  final VoidCallback? onTap;

  const FinalExamCard({
    super.key,
    required this.isEnrolled,
    required this.isExamPublished,
    required this.completionPercentage,
    this.bestAttempt,
    this.onTap,
  });

  bool get _isUnlocked =>
      isEnrolled && isExamPublished && completionPercentage >= 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s4,
        AppSpacing.pageGutter,
        AppSpacing.s2,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.rLg,
        child: DecoratedBox(
          decoration: _isUnlocked
              ? BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: AppRadii.rLg,
                  border: Border.all(
                    color: AppColors.goldLight,
                    width: AppBorders.hairline,
                  ),
                  boxShadow: AppShadows.card,
                )
              : AppDecorations.card,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (_isUnlocked || bestAttempt != null) ? onTap : null,
              borderRadius: AppRadii.rLg,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s5),
                child: Row(
                  children: [
                    _ExamIcon(
                      isUnlocked: _isUnlocked,
                      passed: bestAttempt?.passed,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: _ExamLabel(
                        isUnlocked: _isUnlocked,
                        subtitle: _subtitle,
                      ),
                    ),
                    if (_isUnlocked || bestAttempt != null)
                      const Icon(
                        Icons.chevron_left,
                        color: AppColors.gold,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    if (!isExamPublished) return 'غير متاح حالياً';
    if (!isEnrolled) return 'يجب التسجيل في الكتاب أولاً';
    if (completionPercentage < 1.0) {
      final pct = (completionPercentage * 100).toInt();
      return 'أكمل الدروس أولاً — $pct٪ مكتمل';
    }
    if (bestAttempt != null) {
      final pct = bestAttempt!.scorePercentage;
      final tag = bestAttempt!.passed ? '✓ ناجح' : '✗ راسب';
      return 'أنهيت الاختبار • $pct٪  $tag';
    }
    return 'اضغط لبدء الاختبار الشامل';
  }
}

class _ExamIcon extends StatelessWidget {
  final bool isUnlocked;
  final bool? passed;
  const _ExamIcon({required this.isUnlocked, this.passed});

  @override
  Widget build(BuildContext context) {
    final hasPassed = passed == true;
    final active = isUnlocked || passed != null;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? AppColors.goldLight.withValues(alpha: 0.4)
            : AppColors.paperSunk,
        border: Border.all(
          color: active ? AppColors.goldLight : AppColors.border,
          width: AppBorders.hairline,
        ),
      ),
      child: Icon(
        hasPassed
            ? Icons.emoji_events_outlined
            : isUnlocked
            ? Icons.school_outlined
            : Icons.lock_outline,
        color: active ? AppColors.goldDeep : AppColors.inkFaint,
        size: 20,
      ),
    );
  }
}

class _ExamLabel extends StatelessWidget {
  final bool isUnlocked;
  final String subtitle;
  const _ExamLabel({required this.isUnlocked, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الاختبار الشامل',
          style: AppTextStyles.h3.copyWith(
            fontSize: 17,
            color: isUnlocked ? AppColors.goldDeep : AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkFaint,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
