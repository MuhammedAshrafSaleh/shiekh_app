// lib/features/exam/view/exam_review_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_spacing.dart';
import '../data/exam_repository.dart';
import '../widgets/exam_review_list.dart';

class ExamReviewPage extends StatefulWidget {
  final String bookId;
  final String attemptId;
  final int attemptNumber;

  const ExamReviewPage({
    super.key,
    required this.bookId,
    required this.attemptId,
    required this.attemptNumber,
  });

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends State<ExamReviewPage> {
  List<ExamReviewQuestion>? _questions;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    final result = await context.read<ExamRepository>().getExamReview(
          widget.bookId,
          widget.attemptId,
        );

    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _loading = false;
        _failed = true;
      }),
      (questions) => setState(() {
        _questions = questions;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('مراجعة المحاولة ${widget.attemptNumber}'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: AppSpacing.md),
                        Text('تعذّر تحميل المراجعة',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ExamReviewList(questions: _questions!),
                  ),
      ),
    );
  }
}
