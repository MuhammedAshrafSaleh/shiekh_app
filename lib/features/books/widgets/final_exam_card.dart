// lib/features/books/widgets/final_exam_card.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';

class FinalExamCard extends StatelessWidget {
  final bool isEnrolled;
  final bool isExamPublished;
  final double completionPercentage;
  final VoidCallback? onTap;

  const FinalExamCard({
    super.key,
    required this.isEnrolled,
    required this.isExamPublished,
    required this.completionPercentage,
    this.onTap,
  });

  bool get _isUnlocked =>
      isEnrolled && isExamPublished && completionPercentage >= 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gold = const Color(0xFFD4A017);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isUnlocked ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: _isUnlocked
                ? LinearGradient(
                    colors: [
                      gold.withValues(alpha: 0.15),
                      gold.withValues(alpha: 0.05),
                    ],
                  )
                : null,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isUnlocked
                      ? gold.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  _isUnlocked ? Icons.school : Icons.lock_outline,
                  color: _isUnlocked
                      ? gold
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاختبار الشامل',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _isUnlocked
                            ? gold
                            : colorScheme.onSurface
                                .withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUnlocked)
                Icon(Icons.chevron_left,
                    color: gold.withValues(alpha: 0.7)),
            ],
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
      return 'أكمل الدروس أولاً — $pct% مكتمل';
    }
    return 'اضغط لبدء الاختبار الشامل';
  }
}
