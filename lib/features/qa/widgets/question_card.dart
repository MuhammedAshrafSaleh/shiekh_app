// lib/features/qa/widgets/question_card.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/student_question_entity.dart';

class QuestionCard extends StatelessWidget {
  final StudentQuestionEntity question;

  const QuestionCard({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: question.isAnswered
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Text(
                    question.isAnswered ? 'تمت الإجابة' : 'قيد المراجعة',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: question.isAnswered
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(question.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Question text
            Text(
              question.questionText,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),

            // Answer (if answered)
            if (question.isAnswered && question.answerText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      question.answerText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
