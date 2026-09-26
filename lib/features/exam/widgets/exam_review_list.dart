// lib/features/exam/widgets/exam_review_list.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../data/exam_repository.dart';

class ExamReviewList extends StatelessWidget {
  final List<ExamReviewQuestion> questions;
  const ExamReviewList({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < questions.length; i++) ...[
          ExamReviewItem(index: i, question: questions[i]),
          if (i < questions.length - 1) ...[
            const SizedBox(height: AppSpacing.s3),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s3),
          ],
        ],
      ],
    );
  }
}

class ExamReviewItem extends StatelessWidget {
  final int index;
  final ExamReviewQuestion question;
  const ExamReviewItem({super.key, required this.index, required this.question});

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  McqOptionState _stateFor(String choiceKey) {
    if (choiceKey == question.correctChoice) return McqOptionState.correct;
    if (choiceKey == question.userAnswer && choiceKey != question.correctChoice) {
      return McqOptionState.incorrect;
    }
    return McqOptionState.idle;
  }

  String _choiceLetter(String key) => switch (key) {
        'a' => 'أ',
        'b' => 'ب',
        'c' => 'ج',
        'd' => 'د',
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final choices = [
      ('أ', 'a', question.choiceA),
      ('ب', 'b', question.choiceB),
      ('ج', 'c', question.choiceC),
      ('د', 'd', question.choiceD),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_ar(index + 1)}. ${question.questionText}',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.s3),
        for (final (label, key, text) in choices)
          McqOptionCard(
            label: _choiceLetter(label),
            text: text,
            optionState: _stateFor(key),
          ),
      ],
    );
  }
}
