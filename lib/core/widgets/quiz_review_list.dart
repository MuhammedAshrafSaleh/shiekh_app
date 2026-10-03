// lib/core/widgets/quiz_review_list.dart
//
// Shared answer-review UI for quizzes and practice exams. Extracted verbatim
// from the lesson quiz tab's review phase, then extended with two optional,
// default-off features so the lesson-quiz path renders identically:
//   • [QuizReviewItem.lectureTitle] → a small source-lecture chip (practice).
//   • [QuizReviewItem.isDeleted]    → a tombstone card for questions removed
//     after a practice attempt was submitted.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/insets.dart';
import 'mcq_option_card.dart';

String _ar(int n) {
  const w = '0123456789';
  const a = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final i = w.indexOf(c);
    return i >= 0 ? a[i] : c;
  }).join();
}

/// Neutral presentation model for one reviewed question. Features map their own
/// entities (lesson `QuizReviewQuestion`, practice `PracticeReviewQuestion`)
/// onto this so the core widget stays feature-agnostic.
class QuizReviewItem {
  final String? questionText;
  final String? choiceA;
  final String? choiceB;
  final String? choiceC;
  final String? choiceD;
  final String? correctChoice;
  final String? userAnswer;
  final bool isCorrect;

  /// Optional source-lecture label (practice exams); null hides the chip.
  final String? lectureTitle;

  /// Tombstone — the underlying question no longer exists.
  final bool isDeleted;

  const QuizReviewItem({
    required this.questionText,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.choiceD,
    required this.correctChoice,
    required this.userAnswer,
    required this.isCorrect,
    this.lectureTitle,
    this.isDeleted = false,
  });

  String choiceText(String key) => switch (key) {
    'a' => choiceA ?? '',
    'b' => choiceB ?? '',
    'c' => choiceC ?? '',
    'd' => choiceD ?? '',
    _ => '',
  };
}

/// Full review screen body: optional back header + a scrollable list of cards.
/// Used by the lesson quiz review phase.
class QuizReviewList extends StatelessWidget {
  final List<QuizReviewItem> items;

  /// When non-null, a back header («مراجعة الإجابات») is shown.
  final VoidCallback? onBack;

  const QuizReviewList({super.key, required this.items, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null) ...[
          Container(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: AppColors.ink,
                        ),
                        tooltip: 'رجوع',
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        'مراجعة الإجابات',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
        Expanded(
          child: ListView.separated(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s4,
              AppSpacing.pageGutter,
              AppSpacing.s6 + context.safeBottom,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Divider(height: 1, color: AppColors.border),
            ),
            itemBuilder: (context, index) =>
                QuizReviewCard(index: index, item: items[index]),
          ),
        ),
      ],
    );
  }
}

/// A single reviewed question. Public so other scroll layouts (e.g. the
/// practice result screen) can place cards in their own slivers.
class QuizReviewCard extends StatelessWidget {
  final int index;
  final QuizReviewItem item;

  const QuizReviewCard({super.key, required this.index, required this.item});

  McqOptionState _stateFor(String choice) {
    final isCorrect = choice == item.correctChoice;
    final isUserAnswer = choice == item.userAnswer;
    if (isCorrect) return McqOptionState.correct;
    if (isUserAnswer && !item.isCorrect) return McqOptionState.incorrect;
    return McqOptionState.idle;
  }

  String _choiceLabel(String key) => switch (key) {
    'a' => 'أ',
    'b' => 'ب',
    'c' => 'ج',
    'd' => 'د',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.paperSunk,
                border: Border.all(
                  color: AppColors.border,
                  width: AppBorders.hairline,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _ar(index + 1),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.lectureTitle != null) ...[
                    _LectureChip(title: item.lectureTitle!),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                  Text(
                    item.isDeleted
                        ? 'هذا السؤال تم حذفه'
                        : (item.questionText ?? ''),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.isDeleted
                          ? AppColors.inkFaint
                          : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!item.isDeleted) ...[
          if (item.userAnswer == null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              'لم تتم الإجابة على هذا السؤال',
              style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          for (final choice in ['a', 'b', 'c', 'd'])
            McqOptionCard(
              label: _choiceLabel(choice),
              text: item.choiceText(choice),
              optionState: _stateFor(choice),
              onTap: null,
            ),
        ],
      ],
    );
  }
}

class _LectureChip extends StatelessWidget {
  final String title;
  const _LectureChip({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 13,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: AppSpacing.s1),
          Flexible(
            child: Text(
              title,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.inkMuted,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
