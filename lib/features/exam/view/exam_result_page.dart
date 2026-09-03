// lib/features/exam/view/exam_result_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/certificate_entity.dart';
import '../bloc/exam_state.dart';
import '../data/exam_repository.dart';
import '../widgets/exam_review_list.dart';

class ExamResultPage extends StatefulWidget {
  final ExamCompleted examCompleted;

  const ExamResultPage({super.key, required this.examCompleted});

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  List<ExamReviewQuestion>? _reviewQuestions;
  bool _reviewLoading = true;
  bool _reviewFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchReview();
  }

  Future<void> _fetchReview() async {
    setState(() {
      _reviewLoading = true;
      _reviewFailed = false;
    });

    final result = await context.read<ExamRepository>().getExamReview(
          widget.examCompleted.bookId,
          widget.examCompleted.result.attemptId,
        );

    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _reviewLoading = false;
        _reviewFailed = true;
      }),
      (questions) => setState(() {
        _reviewQuestions = questions;
        _reviewLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.examCompleted.result;
    final settings = widget.examCompleted.settings;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final passed = result.passed;

    final primaryColor = passed ? colorScheme.primary : colorScheme.error;
    final bgColor =
        passed ? colorScheme.primaryContainer : colorScheme.errorContainer;
    final onBgColor =
        passed ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('نتيجة الاختبار'),
        actions: [
          TextButton(
            onPressed: () =>
                context.go('/books/${widget.examCompleted.bookId}'),
            child: const Text('العودة للكتاب'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score ring
              Center(
                child: _ScoreRing(
                  score: result.score,
                  passingPercentage: settings.passingPercentage,
                  passed: passed,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Pass / Fail badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  passed ? 'ناجح  ✓' : 'راسب',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onBgColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Grade label
              if (result.gradeLabel.isNotEmpty)
                Center(
                  child: Text(
                    result.gradeLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ResultStat(
                    value: '${result.correct}',
                    label: 'إجابة صحيحة',
                    color: colorScheme.primary,
                  ),
                  _ResultStat(
                    value: '${result.total - result.correct}',
                    label: 'إجابة خاطئة',
                    color: colorScheme.error,
                  ),
                  _ResultStat(
                    value: '${result.total}',
                    label: 'إجمالي الأسئلة',
                    color: colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Certificate section (if passed)
              if (passed) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFD4A017).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Color(0xFFD4A017), size: 40),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'تهانيّ! لقد حصلت على شهادة إتمام',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF8B6914),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () {
                          final cert = CertificateEntity(
                            id: '',
                            userId: '',
                            bookId: widget.examCompleted.bookId,
                            finalExamAttemptId: result.attemptId,
                            finalScore: result.score,
                            gradeLabel: result.gradeLabel.isEmpty
                                ? null
                                : result.gradeLabel,
                            issuedAt: DateTime.now(),
                          );
                          context.push(
                            '/certificates/${widget.examCompleted.bookId}',
                            extra: cert,
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('عرض وتحميل الشهادة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD4A017),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Back button
              OutlinedButton.icon(
                onPressed: () =>
                    context.go('/books/${widget.examCompleted.bookId}'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('العودة إلى الكتاب'),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Answer Review Section ────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    child: Text(
                      'مراجعة الإجابات',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (_reviewLoading)
                const Center(child: CircularProgressIndicator())
              else if (_reviewFailed)
                Center(
                  child: TextButton.icon(
                    onPressed: _fetchReview,
                    icon: const Icon(Icons.refresh),
                    label: const Text('فشل تحميل المراجعة — إعادة المحاولة'),
                  ),
                )
              else if (_reviewQuestions != null)
                ExamReviewList(questions: _reviewQuestions!),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Score ring ───────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final int score;
  final int passingPercentage;
  final bool passed;
  final Color primaryColor;

  const _ScoreRing({
    required this.score,
    required this.passingPercentage,
    required this.passed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 12,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: primaryColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
              ),
              Text(
                'نسبة النجاح: $passingPercentage%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Result stat ──────────────────────────────────────────────────────────────

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _ResultStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
