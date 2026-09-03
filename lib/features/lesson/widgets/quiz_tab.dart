// lib/features/lesson/widgets/quiz_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../features/lesson/cubit/lesson_cubit.dart';
import '../../../features/lesson/cubit/lesson_state.dart';
import '../../../features/lesson/data/lesson_repository.dart';
import '../../../models/lesson_quiz_attempt_entity.dart';

enum _QuizPhase { intro, loading, error, answering, submitted, review }

// Where the review was launched from — controls what "back" does
enum _ReviewOrigin { result, intro }

class QuizTab extends StatefulWidget {
  final String lessonId;

  /// When true, grading still runs (read-only) but no attempt is recorded via
  /// LessonCubit — used by the admin "preview as student" screen.
  final bool previewMode;

  const QuizTab({super.key, required this.lessonId, this.previewMode = false});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  _QuizPhase _phase = _QuizPhase.intro;
  _ReviewOrigin _reviewOrigin = _ReviewOrigin.result;

  List<dynamic> _questions = [];
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  QuizGradeResult? _result;
  String? _errorMessage;

  List<QuizReviewQuestion> _reviewQuestions = [];

  @override
  void initState() {
    super.initState();
    _preloadQuestions();
  }

  // Pre-fetch questions silently so answering starts instantly.
  Future<void> _preloadQuestions() async {
    final repo = context.read<LessonRepository>();
    final result = await repo.getQuizQuestions(widget.lessonId);
    if (!mounted) return;
    result.fold((_) {}, (q) => setState(() => _questions = q));
  }

  Future<void> _startQuiz() async {
    if (_questions.isEmpty) {
      setState(() => _phase = _QuizPhase.loading);
      final repo = context.read<LessonRepository>();
      final result = await repo.getQuizQuestions(widget.lessonId);
      if (!mounted) return;
      result.fold(
        (failure) => setState(() {
          _phase = _QuizPhase.error;
          _errorMessage = failure.message;
        }),
        (questions) => setState(() {
          _questions = questions;
          _currentIndex = 0;
          _answers.clear();
          _phase = _QuizPhase.answering;
        }),
      );
    } else {
      setState(() {
        _currentIndex = 0;
        _answers.clear();
        _phase = _QuizPhase.answering;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _phase = _QuizPhase.loading);
    final repo = context.read<LessonRepository>();

    final result = widget.previewMode
        ? await repo.gradeQuiz(widget.lessonId, _answers)
        : await repo.submitQuiz(widget.lessonId, _answers);

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _phase = _QuizPhase.error;
            _errorMessage = failure.message;
          });
        }
      },
      (grade) {
        if (mounted) {
          setState(() {
            _result = grade;
            _phase = _QuizPhase.submitted;
          });
          if (!widget.previewMode) {
            final newAttempt = LessonQuizAttemptEntity(
              id: '',
              userId: '',
              lessonId: widget.lessonId,
              attemptNumber: grade.attemptsUsed,
              scorePercentage: grade.percentage,
              passed: grade.percentage >= 60,
              submittedAt: DateTime.now(),
            );
            context
                .read<LessonCubit>()
                .markQuizAttempted(grade.attemptsUsed, newAttempt);
          }
        }
      },
    );
  }

  Future<void> _loadReview(int? attemptNumber, _ReviewOrigin origin) async {
    setState(() => _phase = _QuizPhase.loading);
    final repo = context.read<LessonRepository>();
    final result = await repo.getQuizReview(
      widget.lessonId,
      attemptNumber: attemptNumber,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _phase = _QuizPhase.error;
        _errorMessage = failure.message;
      }),
      (questions) => setState(() {
        _reviewQuestions = questions;
        _reviewOrigin = origin;
        _phase = _QuizPhase.review;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _QuizPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_phase == _QuizPhase.error) {
      return ErrorState(
        message: _errorMessage ?? 'حدث خطأ',
        onRetry: () => setState(() => _phase = _QuizPhase.intro),
      );
    }

    if (_phase == _QuizPhase.review) {
      return _QuizReview(
        questions: _reviewQuestions,
        onBack: () => setState(() => _phase == _QuizPhase.review
            ? _phase = _reviewOrigin == _ReviewOrigin.result
                ? _QuizPhase.submitted
                : _QuizPhase.intro
            : null),
      );
    }

    if (_phase == _QuizPhase.intro) {
      return BlocBuilder<LessonCubit, LessonState>(
        buildWhen: (prev, next) =>
            prev is LessonLoaded &&
            next is LessonLoaded &&
            (prev.quizAttemptsUsed != next.quizAttemptsUsed ||
                prev.pastAttempts.length != next.pastAttempts.length),
        builder: (context, state) {
          final loaded = state is LessonLoaded ? state : null;
          final questionCount = loaded?.quizQuestionCount ?? _questions.length;
          final attemptsUsed = loaded?.quizAttemptsUsed ?? 0;
          final pastAttempts = loaded?.pastAttempts ?? const [];
          return _QuizIntro(
            questionCount: questionCount,
            attemptsUsed: attemptsUsed,
            pastAttempts: pastAttempts,
            onStart: _startQuiz,
            onReview: (n) => _loadReview(n, _ReviewOrigin.intro),
          );
        },
      );
    }

    if (_questions.isEmpty) {
      return const EmptyState(
        icon: Icons.quiz_outlined,
        message: 'لا توجد أسئلة لهذا الدرس',
      );
    }

    if (_phase == _QuizPhase.submitted && _result != null) {
      return _QuizResult(
        result: _result!,
        onRetry: () => setState(() => _phase = _QuizPhase.intro),
        onReview: () => _loadReview(null, _ReviewOrigin.result),
      );
    }

    final question = _questions[_currentIndex];
    final total = _questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'السؤال ${_currentIndex + 1} من $total',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                '${_answers.length} / $total',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: (_currentIndex + 1) / total),
          const SizedBox(height: AppSpacing.lg),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.6,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final choice in ['a', 'b', 'c', 'd'])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: McqOptionCard(
                label: _choiceLabel(choice),
                text: question.choiceLabel(choice),
                optionState: _answers[question.id] == choice
                    ? McqOptionState.selected
                    : McqOptionState.idle,
                onTap: () => setState(() => _answers[question.id] = choice),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (_currentIndex > 0)
                TextButton.icon(
                  onPressed: () => setState(() => _currentIndex--),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('السابق'),
                ),
              const Spacer(),
              if (_currentIndex < total - 1)
                FilledButton.icon(
                  onPressed: () => setState(() => _currentIndex++),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('التالي'),
                )
              else
                FilledButton.icon(
                  onPressed: _answers.length < total
                      ? _showUnansweredWarning
                      : _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('تسليم الاختبار'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _choiceLabel(String key) => switch (key) {
        'a' => 'أ',
        'b' => 'ب',
        'c' => 'ج',
        'd' => 'د',
        _ => key,
      };

  void _showUnansweredWarning() {
    final unanswered = _questions.length - _answers.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أسئلة غير مجاب عليها'),
        content: Text(
          'لديك $unanswered سؤال لم تجب عليه بعد. هل تريد التسليم على أي حال؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submit();
            },
            child: const Text('تسليم'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Intro screen
// ─────────────────────────────────────────────────────────────

class _QuizIntro extends StatelessWidget {
  final int questionCount;
  final int attemptsUsed;
  final List<LessonQuizAttemptEntity> pastAttempts;
  final VoidCallback onStart;
  final void Function(int attemptNumber) onReview;

  const _QuizIntro({
    required this.questionCount,
    required this.attemptsUsed,
    required this.pastAttempts,
    required this.onStart,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exhausted = attemptsUsed >= 2;
    final attemptsRemaining = 2 - attemptsUsed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Icon(Icons.quiz_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'اختبار الدرس',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            icon: Icons.help_outline,
            label: 'عدد الأسئلة',
            value: '$questionCount سؤال',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.repeat,
            label: 'المحاولات المتبقية',
            value: '$attemptsRemaining من 2',
            valueColor: attemptsRemaining == 0
                ? theme.colorScheme.error
                : attemptsRemaining == 1
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
          ),

          // Past attempt score cards
          if (pastAttempts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('المحاولات السابقة',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                )),
            const SizedBox(height: AppSpacing.sm),
            for (final attempt in pastAttempts)
              _AttemptCard(
                attempt: attempt,
                onReview: () => onReview(attempt.attemptNumber),
              ),
          ],

          const SizedBox(height: AppSpacing.md),
          if (!exhausted) ...[
            Text(
              'أجب على جميع الأسئلة ثم اضغط تسليم',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ الاختبار'),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'استنفدت جميع المحاولات',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => onReview(pastAttempts.last.attemptNumber),
              icon: const Icon(Icons.checklist),
              label: const Text('مراجعة آخر محاولة'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final LessonQuizAttemptEntity attempt;
  final VoidCallback onReview;

  const _AttemptCard({required this.attempt, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = attempt.passed;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              passed ? Icons.check_circle : Icons.cancel,
              color: passed ? Colors.green : theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'المحاولة ${attempt.attemptNumber}',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              '${attempt.scorePercentage}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onReview,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('مراجعة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Result screen
// ─────────────────────────────────────────────────────────────

class _QuizResult extends StatelessWidget {
  final QuizGradeResult result;
  final VoidCallback onRetry;
  final VoidCallback onReview;

  const _QuizResult({
    required this.result,
    required this.onRetry,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = result.percentage >= 60;
    final canRetry = result.attemptsUsed < 2;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: passed
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
            child: Text(
              '${result.percentage}%',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: passed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            passed ? 'أحسنت!' : 'راجع الدرس وحاول مجدداً',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${result.correct} إجابة صحيحة من أصل ${result.total}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'المحاولة ${result.attemptsUsed} من 2',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.checklist),
            label: const Text('مراجعة الإجابات'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canRetry)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة الاختبار'),
            )
          else
            Text(
              'استنفدت جميع المحاولات',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Review screen
// ─────────────────────────────────────────────────────────────

class _QuizReview extends StatelessWidget {
  final List<QuizReviewQuestion> questions;
  final VoidCallback onBack;

  const _QuizReview({required this.questions, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Back header
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'العودة',
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('مراجعة الإجابات',
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return _ReviewQuestionCard(
                index: index,
                question: q,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final QuizReviewQuestion question;

  const _ReviewQuestionCard({required this.index, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question number + text
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  question.questionText,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),

        if (question.userAnswer == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'لم يتم الإجابة على هذا السؤال',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        for (final choice in ['a', 'b', 'c', 'd'])
          McqOptionCard(
            label: _choiceLabel(choice),
            text: question.choiceText(choice),
            optionState: _stateFor(choice),
            onTap: null,
          ),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  McqOptionState _stateFor(String choice) {
    final isCorrect = choice == question.correctChoice;
    final isUserAnswer = choice == question.userAnswer;

    if (isCorrect) return McqOptionState.correct;
    if (isUserAnswer && !question.isCorrect) return McqOptionState.incorrect;
    return McqOptionState.idle;
  }

  String _choiceLabel(String key) => switch (key) {
        'a' => 'أ',
        'b' => 'ب',
        'c' => 'ج',
        'd' => 'د',
        _ => key,
      };
}

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
