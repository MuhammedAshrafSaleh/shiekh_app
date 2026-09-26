// lib/features/qa/widgets/question_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/student_question_entity.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question});

  final StudentQuestionEntity question;

  String _formatDate(DateTime date) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    String ar(int n) => n.toString().split('').map((c) {
          final i = w.indexOf(c);
          return i >= 0 ? a[i] : c;
        }).join();
    return '${ar(date.day)}/${ar(date.month)}/${ar(date.year)}';
  }

  @override
  Widget build(BuildContext context) {
    final answered = question.isAnswered;

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s2,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: status badge + date
            Row(
              children: [
                _StatusBadge(answered: answered),
                const Spacer(),
                Text(
                  _formatDate(question.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),

            // Question text
            Text(
              question.questionText,
              style: AppTextStyles.body.copyWith(
                color: AppColors.ink,
                height: 1.6,
              ),
            ),

            // Answer section
            if (answered && question.answerText != null) ...[
              const SizedBox(height: AppSpacing.s3),
              const Divider(
                height: 1,
                thickness: AppBorders.hairline,
                color: AppColors.border,
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      question.answerText!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    final bg = answered
        ? AppColors.primary.withValues(alpha: 0.10)
        : AppColors.gold.withValues(alpha: 0.12);
    final fg = answered ? AppColors.primary : AppColors.goldDeep;
    final label = answered ? 'تمت الإجابة' : 'قيد المراجعة';

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.s2),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
