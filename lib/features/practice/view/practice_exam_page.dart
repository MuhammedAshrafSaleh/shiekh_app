// lib/features/practice/view/practice_exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../core/widgets/show_confirm_dialog.dart';
import '../../exam/widgets/timer_display.dart';
import '../bloc/practice_exam_bloc.dart';
import '../bloc/practice_exam_event.dart';
import '../bloc/practice_exam_state.dart';
import '../data/practice_repository.dart';
import '../widgets/practice_navigator_grid.dart';

String _ar(int n) {
  const w = '0123456789';
  const a = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final i = w.indexOf(c);
    return i >= 0 ? a[i] : c;
  }).join();
}

String _choiceLetter(String key) => switch (key) {
  'a' => 'أ',
  'b' => 'ب',
  'c' => 'ج',
  'd' => 'د',
  _ => key,
};

class PracticeExamPage extends StatelessWidget {
  const PracticeExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PracticeExamBloc, PracticeExamState>(
      listener: (context, state) {
        if (state is PracticeExamError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          PracticeExamLoading() => const _LoadingScaffold(),
          PracticeExamError(:final message) => _ErrorScaffold(message: message),
          PracticeExamInProgress() => _InProgressView(state: state),
          PracticeExamCompleted(:final result) => _CompletedScaffold(
            result: result,
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheikhyPageHeader(title: 'اختبر نفسك', showBack: true),
          Expanded(
            child: SheikhyErrorState(
              heading: 'تعذّر بدء الاختبار',
              message: message,
              onRetry: () => context.read<PracticeExamBloc>().add(
                const PracticeExamStarted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── In-progress ─────────────────────────────────────────────────────────────

Future<void> _showLeaveDialog(BuildContext context) async {
  final leave = await showConfirmDialog(
    context,
    title: 'تأكيد الخروج',
    message: 'لو خرجت الآن سيتم فقدان تقدّمك ولن يتم حفظ أي شيء.',
    confirmLabel: 'اخرج',
    cancelLabel: 'المتابعة',
    isDestructive: true,
    icon: Icons.logout_rounded,
  );
  if (leave && context.mounted) context.pop(); // discard — nothing is saved
}

class _InProgressView extends StatelessWidget {
  final PracticeExamInProgress state;
  const _InProgressView({required this.state});

  @override
  Widget build(BuildContext context) {
    final q = state.currentQuestion;
    final selected = state.answers[q.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showLeaveDialog(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QuestionBar(
              currentIndex: state.currentIndex,
              totalQuestions: state.questions.length,
              timerEnabled: state.timerEnabled,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s4,
                  AppSpacing.pageGutter,
                  AppSpacing.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      q.questionText,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    for (final choice in ['a', 'b', 'c', 'd'])
                      McqOptionCard(
                        label: _choiceLetter(choice),
                        text: q.choiceLabel(choice),
                        optionState: selected == choice
                            ? McqOptionState.selected
                            : McqOptionState.idle,
                        onTap: (state.isSubmitting || state.isTimeUp)
                            ? null
                            : () => context.read<PracticeExamBloc>().add(
                                PracticeExamAnswerSelected(q.id, choice),
                              ),
                      ),
                    const SizedBox(height: AppSpacing.s2),
                    PracticeNavigatorGrid(
                      questionIds: [for (final x in state.questions) x.id],
                      answers: state.answers,
                      currentIndex: state.currentIndex,
                      onNavigate: (i) => context.read<PracticeExamBloc>().add(
                        PracticeExamNavigateTo(i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s2,
                  AppSpacing.pageGutter,
                  AppSpacing.s4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.submitError != null) ...[
                      _SubmitErrorBanner(
                        message: state.submitError!,
                        onRetry: () => context.read<PracticeExamBloc>().add(
                          const PracticeExamSubmitted(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: SheikhyButton.secondary(
                            fullWidth: true,
                            label: 'السابق',
                            onPressed:
                                state.currentIndex > 0 && !state.isSubmitting
                                ? () => context.read<PracticeExamBloc>().add(
                                    PracticeExamNavigateTo(
                                      state.currentIndex - 1,
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: state.currentIndex < state.questions.length - 1
                              ? SheikhyButton.primary(
                                  fullWidth: true,
                                  label: 'التالي',
                                  onPressed: state.isSubmitting
                                      ? null
                                      : () => context
                                            .read<PracticeExamBloc>()
                                            .add(
                                              PracticeExamNavigateTo(
                                                state.currentIndex + 1,
                                              ),
                                            ),
                                  icon: const Icon(
                                    Icons.arrow_back_ios,
                                    size: 16,
                                  ),
                                )
                              : SheikhyButton.primary(
                                  fullWidth: true,
                                  isLoading: state.isSubmitting,
                                  label: 'تسليم',
                                  onPressed: state.isSubmitting
                                      ? null
                                      : () => _confirmSubmit(context, state),
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    PracticeExamInProgress state,
  ) async {
    final answered = state.answeredCount;
    final total = state.questions.length;
    final hasUnanswered = state.unansweredCount > 0;

    final confirmed = await showConfirmDialog(
      context,
      title: 'هل أنت متأكد من إنهاء الاختبار؟',
      message: hasUnanswered
          ? 'لقد أجبت على ${_ar(answered)} من ${_ar(total)} سؤال، '
                'الأسئلة المتبقية ستُعتبر خاطئة.'
          : 'لقد أجبت على جميع الأسئلة. هل تريد تسليم الاختبار الآن؟',
      confirmLabel: 'تسليم الاختبار',
      cancelLabel: 'مراجعة الأسئلة',
      isDestructive: false,
      icon: hasUnanswered
          ? Icons.warning_amber_rounded
          : Icons.check_circle_outline_rounded,
    );

    if (confirmed && context.mounted) {
      context.read<PracticeExamBloc>().add(const PracticeExamSubmitted());
    }
  }
}

class _SubmitErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SubmitErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: AppBorders.hairline,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              'تعذّر تسليم الاختبار. $message',
              style: AppTextStyles.small.copyWith(color: AppColors.danger),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'إعادة المحاولة',
              style: AppTextStyles.small.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBar extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final bool timerEnabled;

  const _QuestionBar({
    required this.currentIndex,
    required this.totalQuestions,
    required this.timerEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      foregroundDecoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
      ),
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
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: AppColors.ink,
                  ),
                  tooltip: 'رجوع',
                  onPressed: () => _showLeaveDialog(context),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سؤال ${_ar(currentIndex + 1)} من',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkMuted,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      _ar(totalQuestions),
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (timerEnabled)
                  BlocSelector<PracticeExamBloc, PracticeExamState, int>(
                    selector: (s) =>
                        s is PracticeExamInProgress ? s.secondsRemaining : 0,
                    builder: (_, secs) => TimerDisplay(secondsRemaining: secs),
                  ),
                const SizedBox(width: AppSpacing.s2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Completed (Phase 5 minimal result; full result + review is Phase 6) ─────

class _CompletedScaffold extends StatelessWidget {
  final PracticeSubmitResult result;
  const _CompletedScaffold({required this.result});

  @override
  Widget build(BuildContext context) {
    final passed = result.score >= 60;
    final color = passed ? AppColors.success : AppColors.gold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheikhyPageHeader(title: 'نتيجة الاختبار'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageGutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                          border: Border.all(color: color, width: 3),
                        ),
                        child: Text(
                          '${_ar(result.score)}٪',
                          style: AppTextStyles.h2.copyWith(color: color),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text('تم تسليم الاختبار', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'أجبت على ${_ar(result.correct)} من '
                        '${_ar(result.total)} إجابة صحيحة',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.inkMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      // TODO(phase-6): replace with full result + per-lecture
                      // breakdown + review screen.
                      SheikhyButton.primary(
                        fullWidth: true,
                        label: 'العودة',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
