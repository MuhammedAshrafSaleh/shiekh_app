// lib/features/practice/view/practice_result_page.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/quiz_review_list.dart';
import '../../../core/widgets/sheikhy_card.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../models/practice_lecture_breakdown.dart';
import '../../../models/practice_review_question.dart';

String _ar(Object n) {
  const w = '0123456789';
  const a = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final i = w.indexOf(c);
    return i >= 0 ? a[i] : c;
  }).join();
}

QuizReviewItem _toItem(PracticeReviewQuestion r) => QuizReviewItem(
  questionText: r.questionText,
  choiceA: r.choiceA,
  choiceB: r.choiceB,
  choiceC: r.choiceC,
  choiceD: r.choiceD,
  correctChoice: r.correctChoice,
  userAnswer: r.userAnswer,
  isCorrect: r.isCorrect,
  lectureTitle: r.lessonTitle,
  isDeleted: r.isDeleted,
);

/// Shared result + review screen for a practice attempt — used both right after
/// submission and when reopening a past attempt from history. Shows the total
/// score, a per-lecture breakdown, and the full per-question review (each
/// question labelled with its source lecture).
class PracticeResultPage extends StatelessWidget {
  final int score;
  final int correct;
  final int total;
  final List<PracticeLectureBreakdown> breakdown;
  final List<PracticeReviewQuestion> review;

  /// Shown only from history (null right after submission).
  final DateTime? createdAt;
  final int? durationSeconds;

  const PracticeResultPage({
    super.key,
    required this.score,
    required this.correct,
    required this.total,
    required this.breakdown,
    required this.review,
    this.createdAt,
    this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final items = [for (final r in review) _toItem(r)];

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheikhyPageHeader(title: 'نتيجة الاختبار', showBack: true),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pageGutter),
                    child: _ScoreHeader(
                      score: score,
                      correct: correct,
                      total: total,
                      durationSeconds: durationSeconds,
                    ),
                  ),
                ),
                if (breakdown.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.pageGutter,
                        0,
                        AppSpacing.pageGutter,
                        AppSpacing.s2,
                      ),
                      child: _BreakdownCard(breakdown: breakdown),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.pageGutter,
                      AppSpacing.s5,
                      AppSpacing.pageGutter,
                      AppSpacing.s3,
                    ),
                    child: Text(
                      'مراجعة الإجابات',
                      style: AppTextStyles.h3.copyWith(color: AppColors.ink),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.pageGutter,
                    0,
                    AppSpacing.pageGutter,
                    AppSpacing.s6 + context.safeBottom,
                  ),
                  sliver: SliverList.separated(
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final int score;
  final int correct;
  final int total;
  final int? durationSeconds;

  const _ScoreHeader({
    required this.score,
    required this.correct,
    required this.total,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final passed = score >= 60;
    final color = passed ? AppColors.success : AppColors.gold;
    final duration = durationSeconds;

    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 3),
          ),
          child: Text(
            '${_ar(score)}٪',
            style: AppTextStyles.display.copyWith(color: color),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'أجبت على ${_ar(correct)} من ${_ar(total)} إجابة صحيحة',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        if (duration != null) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            'الوقت المستغرق: ${_formatDuration(duration)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${_ar(m)}:${_ar(s.toString().padLeft(2, '0'))}';
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<PracticeLectureBreakdown> breakdown;
  const _BreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return SheikhyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'التفصيل حسب المحاضرة',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s3),
          for (var i = 0; i < breakdown.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s3),
            _BreakdownRow(row: breakdown[i]),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final PracticeLectureBreakdown row;
  const _BreakdownRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final ratio = row.total > 0 ? row.correct / row.total : 0.0;
    final color = ratio >= 0.6 ? AppColors.success : AppColors.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.lessonTitle,
                style: AppTextStyles.small.copyWith(color: AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              '${_ar(row.correct)}/${_ar(row.total)}',
              style: AppTextStyles.small.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        ClipRRect(
          borderRadius: AppRadii.rPill,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.paperSunk,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
