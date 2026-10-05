// lib/features/practice/view/practice_attempt_review_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../data/practice_repository.dart';
import 'practice_result_page.dart';

/// Loads a past practice attempt from history and renders it via the shared
/// [PracticeResultPage] (same score / breakdown / review UI as post-submission).
class PracticeAttemptReviewPage extends StatefulWidget {
  final String attemptId;
  const PracticeAttemptReviewPage({super.key, required this.attemptId});

  @override
  State<PracticeAttemptReviewPage> createState() =>
      _PracticeAttemptReviewPageState();
}

class _PracticeAttemptReviewPageState extends State<PracticeAttemptReviewPage> {
  late Future<void> _future;
  PracticeAttemptReview? _review;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final result = await context.read<PracticeRepository>().getAttemptReview(
      widget.attemptId,
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() => _error = f.message),
      (r) => setState(() => _review = r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (_error != null) {
          return Scaffold(
            backgroundColor: AppColors.paper,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheikhyPageHeader(
                  title: 'نتيجة الاختبار',
                  showBack: true,
                ),
                Expanded(
                  child: SheikhyErrorState(
                    heading: 'تعذّر تحميل المراجعة',
                    message: _error!,
                    onRetry: () {
                      setState(() {
                        _error = null;
                        _future = _load();
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }

        final review = _review;
        if (review == null) {
          return Scaffold(
            backgroundColor: AppColors.paper,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return PracticeResultPage(
          score: review.score,
          correct: review.correct,
          total: review.total,
          breakdown: review.breakdown,
          review: review.review,
          createdAt: review.createdAt,
          durationSeconds: review.durationSeconds,
        );
      },
    );
  }
}
