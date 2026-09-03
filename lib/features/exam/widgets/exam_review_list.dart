// lib/features/exam/widgets/exam_review_list.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../data/exam_repository.dart';

class ExamReviewList extends StatelessWidget {
  final List<ExamReviewQuestion> questions;
  const ExamReviewList({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < questions.length; i++) ...[
          ExamReviewItem(index: i, question: questions[i]),
          if (i < questions.length - 1)
            Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              height: AppSpacing.lg,
            ),
        ],
      ],
    );
  }
}

class ExamReviewItem extends StatelessWidget {
  final int index;
  final ExamReviewQuestion question;
  const ExamReviewItem({super.key, required this.index, required this.question});

  McqOptionState _stateFor(String choiceKey) {
    if (choiceKey == question.correctChoice) return McqOptionState.correct;
    if (choiceKey == question.userAnswer && choiceKey != question.correctChoice) {
      return McqOptionState.incorrect;
    }
    return McqOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choices = [
      ('أ', 'a', question.choiceA),
      ('ب', 'b', question.choiceB),
      ('ج', 'c', question.choiceC),
      ('د', 'd', question.choiceD),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${index + 1}. ${question.questionText}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (label, key, text) in choices)
          McqOptionCard(
            label: label,
            text: text,
            optionState: _stateFor(key),
          ),
      ],
    );
  }
}
