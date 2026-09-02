// lib/features/exam/view/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart' as hs;
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../models/final_exam_attempt_entity.dart';
import '../bloc/exam_bloc.dart';
import '../bloc/exam_event.dart';
import '../bloc/exam_state.dart';
import '../widgets/exam_navigator_grid.dart';
import '../widgets/timer_display.dart';

class ExamPage extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const ExamPage({super.key, required this.bookId, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamBloc, ExamState>(
      listener: (context, state) {
        if (state is ExamCompleted) {
          context.go(
            '/books/$bookId/exam/result',
            extra: state,
          );
        }
        if (state is ExamError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          ExamInitial() || ExamLoading() => Scaffold(
              appBar: AppBar(title: Text(bookTitle)),
              body: const Center(child: CircularProgressIndicator()),
            ),
          ExamMetaLoaded() => _IntroView(
              state: state,
              bookTitle: bookTitle,
            ),
          ExamInProgress() => _InProgressView(
              state: state,
              bookTitle: bookTitle,
            ),
          ExamCompleted() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ExamError(:final message) => Scaffold(
              appBar: AppBar(title: Text(bookTitle)),
              body: ErrorState(
                message: message,
                onRetry: () => context
                    .read<ExamBloc>()
                    .add(ExamLoadRequested(bookId)),
              ),
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ─── Intro View ──────────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  final ExamMetaLoaded state;
  final String bookTitle;

  const _IntroView({required this.state, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle),
        actions: [
          if (state.pastAttempts.isNotEmpty)
            TextButton(
              onPressed: () => _showPastAttempts(context),
              child: const Text('المحاولات السابقة'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exam icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'الاختبار الشامل',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                bookTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatTile(
                    icon: Icons.quiz_outlined,
                    value: '${state.questionCount}',
                    label: 'سؤال',
                  ),
                  _StatTile(
                    icon: Icons.timer_outlined,
                    value: '${s.timeLimitMinutes}',
                    label: 'دقيقة',
                  ),
                  _StatTile(
                    icon: Icons.percent,
                    value: '${s.passingPercentage}%',
                    label: 'للنجاح',
                  ),
                  _StatTile(
                    icon: Icons.repeat,
                    value:
                        '${s.maxAttempts - state.attemptsUsed}/${s.maxAttempts}',
                    label: 'محاولات',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Lock reasons
              if (!state.settings.isPublished)
                _WarningBanner(
                    'الاختبار غير متاح حالياً',
                    Icons.lock_outlined),
              if (state.settings.isPublished && state.questionCount == 0)
                _WarningBanner(
                    'لا توجد أسئلة في الاختبار بعد',
                    Icons.help_outline),
              if (state.attemptsExhausted)
                _WarningBanner(
                    'لقد استنفدت جميع محاولاتك المسموحة (${s.maxAttempts}/${s.maxAttempts})',
                    Icons.block_outlined),

              if (state.isLocked) const SizedBox(height: AppSpacing.md),

              // Past attempts summary
              if (state.pastAttempts.isNotEmpty && !state.attemptsExhausted) ...[
                Text(
                  'آخر محاولة: ${state.pastAttempts.last.scorePercentage}%'
                  ' — ${state.pastAttempts.last.passed ? "ناجح ✓" : "راسب"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Start button (CC-15/CC-16/CC-13)
              FilledButton.icon(
                onPressed: state.isLocked || state.isStarting
                    ? null
                    : () => context.read<ExamBloc>().add(const ExamStartRequested()),
                icon: state.isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(state.attemptsUsed == 0
                    ? 'بدء الاختبار'
                    : 'إعادة الاختبار'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPastAttempts(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => _PastAttemptsSheet(attempts: state.pastAttempts),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const _WarningBanner(this.message, this.icon);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastAttemptsSheet extends StatelessWidget {
  final List<FinalExamAttemptEntity> attempts;
  const _PastAttemptsSheet({required this.attempts});

  String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          // Drag handle + title
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              hs.AppSpacing.pageGutter,
              hs.AppSpacing.s3,
              hs.AppSpacing.pageGutter,
              hs.AppSpacing.s3,
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: hs.AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadii.rPill,
                    ),
                  ),
                ),
                Text(
                  'المحاولات السابقة',
                  style: AppTextStyles.h3,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              itemCount: attempts.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final a = attempts[i];
                final passed = a.passed;
                final accentColor =
                    passed ? AppColors.primary : AppColors.danger;
                return Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: hs.AppSpacing.pageGutter,
                    vertical: hs.AppSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      // Attempt number circle
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _ar(a.attemptNumber),
                            style: AppTextStyles.small.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: hs.AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_ar(a.scorePercentage)}٪ — ${passed ? "ناجح" : "راسب"}',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (a.submittedAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                dateFormat.format(a.submittedAt!.toLocal()),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.inkFaint,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        color: accentColor,
                        size: 22,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── In-Progress View ─────────────────────────────────────────────────────────

class _InProgressView extends StatelessWidget {
  final ExamInProgress state;
  final String bookTitle;

  const _InProgressView({required this.state, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = state.currentQuestion;
    final selectedChoice = state.answers[q.id];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: BlocSelector<ExamBloc, ExamState, int>(
          selector: (s) =>
              s is ExamInProgress ? s.secondsRemaining : 0,
          builder: (_, secs) => TimerDisplay(secondsRemaining: secs),
        ),
        centerTitle: false,
        actions: [
          // Question counter
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
            child: Center(
              child: Text(
                '${state.currentIndex + 1} / ${state.questions.length}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Navigator grid
            ExamNavigatorGrid(
              questions: state.questions,
              answers: state.answers,
              currentIndex: state.currentIndex,
              onNavigate: (i) =>
                  context.read<ExamBloc>().add(ExamNavigateTo(i)),
            ),
            const Divider(height: 1),

            // Question + choices
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.questionText,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final choice in ['a', 'b', 'c', 'd'])
                      McqOptionCard(
                        label: _choiceLetter(choice),
                        text: q.choiceLabel(choice),
                        optionState: selectedChoice == choice
                            ? McqOptionState.selected
                            : McqOptionState.idle,
                        onTap: state.isSubmitting
                            ? null
                            : () => context.read<ExamBloc>().add(
                                  ExamAnswerSelected(q.id, choice),
                                ),
                      ),
                  ],
                ),
              ),
            ),

            // Prev / Next / Submit
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: state.currentIndex > 0 && !state.isSubmitting
                        ? () => context.read<ExamBloc>().add(
                              ExamNavigateTo(state.currentIndex - 1),
                            )
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('السابق'),
                  ),
                  const Spacer(),
                  if (state.currentIndex < state.questions.length - 1)
                    FilledButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.read<ExamBloc>().add(
                                ExamNavigateTo(state.currentIndex + 1),
                              ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('التالي'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => _confirmSubmit(context),
                      icon: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('تسليم'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Task 4.4: submit confirm with unanswered warning
  void _confirmSubmit(BuildContext context) {
    final unanswered = state.unansweredCount;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسليم الاختبار'),
        content: Text(unanswered > 0
            ? 'لديك $unanswered سؤال غير مُجاب. هل تريد التسليم على أي حال؟'
            : 'هل أنت متأكد من تسليم الاختبار؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop();
              context.read<ExamBloc>().add(const ExamSubmitConfirmed());
            },
            child: const Text('تسليم'),
          ),
        ],
      ),
    );
  }

  String _choiceLetter(String key) {
    return switch (key) {
      'a' => 'أ',
      'b' => 'ب',
      'c' => 'ج',
      'd' => 'د',
      _ => key,
    };
  }
}

// Empty state for exam not found
class ExamNotFoundView extends StatelessWidget {
  const ExamNotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاختبار الشامل')),
      body: const EmptyState(
        icon: Icons.assignment_outlined,
        message: 'الاختبار غير متاح حالياً',
      ),
    );
  }
}
