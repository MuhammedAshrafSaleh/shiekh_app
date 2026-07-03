// lib/features/lesson/widgets/quiz_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../features/lesson/data/lesson_repository.dart';
import '../cubit/lesson_cubit.dart';

// Local states for the quiz tab — pure UI state, not business state
enum _QuizPhase { loading, error, answering, submitted }

class QuizTab extends StatefulWidget {
  final String lessonId;

  const QuizTab({super.key, required this.lessonId});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  _QuizPhase _phase = _QuizPhase.loading;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  QuizGradeResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _phase = _QuizPhase.loading);
    final repo = context.read<LessonRepository>();
    final result = await repo.getQuizQuestions(widget.lessonId);
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _phase = _QuizPhase.error;
            _errorMessage = failure.message;
          });
        }
      },
      (questions) {
        if (mounted) {
          setState(() {
            _questions = questions;
            _phase = _QuizPhase.answering;
          });
        }
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _phase = _QuizPhase.loading);
    final repo = context.read<LessonRepository>();
    final result = await repo.gradeQuiz(widget.lessonId, _answers);
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
          context.read<LessonCubit>().markQuizAttempted();
        }
      },
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
        onRetry: _loadQuestions,
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
        onRetry: () {
          setState(() {
            _answers.clear();
            _currentIndex = 0;
            _phase = _QuizPhase.answering;
          });
        },
      );
    }

    final question = _questions[_currentIndex];
    final total = _questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
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

          // Question text
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.6,
                ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Choices
          for (final choice in ['a', 'b', 'c', 'd'])
            Padding(
              padding:
                  const EdgeInsets.only(bottom: AppSpacing.sm),
              child: McqOptionCard(
                label: _choiceLabel(choice),
                text: question.choiceLabel(choice),
                optionState: _answers[question.id] == choice
                    ? McqOptionState.selected
                    : McqOptionState.idle,
                onTap: () {
                  setState(() => _answers[question.id] = choice);
                },
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          // Navigation buttons
          Row(
            children: [
              if (_currentIndex > 0)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _currentIndex--),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('السابق'),
                ),
              const Spacer(),
              if (_currentIndex < total - 1)
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _currentIndex++),
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

  String _choiceLabel(String key) {
    return switch (key) {
      'a' => 'أ',
      'b' => 'ب',
      'c' => 'ج',
      'd' => 'د',
      _ => key,
    };
  }

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

class _QuizResult extends StatelessWidget {
  final QuizGradeResult result;
  final VoidCallback onRetry;

  const _QuizResult({required this.result, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = result.percentage >= 60;

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
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة الاختبار'),
          ),
        ],
      ),
    );
  }
}
