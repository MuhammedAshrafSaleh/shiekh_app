// lib/features/exam/view/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart' as hs;
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
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
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          ExamInitial() || ExamLoading() => _LoadingScaffold(
              bookTitle: bookTitle,
            ),
          ExamMetaLoaded() => _IntroView(
              state: state,
              bookTitle: bookTitle,
            ),
          ExamInProgress() => _InProgressView(
              state: state,
              bookTitle: bookTitle,
            ),
          ExamCompleted() => Scaffold(
              backgroundColor: AppColors.paper,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ExamError(:final message) => _ErrorScaffold(
              bookId: bookId,
              message: message,
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ─── Loading scaffold ────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  final String bookTitle;
  const _LoadingScaffold({required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          SheikhyPageHeader(title: bookTitle, showBack: true),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error scaffold ──────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final String bookId;
  final String message;
  const _ErrorScaffold({required this.bookId, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          SheikhyPageHeader(title: 'الاختبار النهائي', showBack: true),
          Expanded(
            child: SheikhyErrorState(
              heading: 'تعذّر تحميل الاختبار',
              message: message,
              onRetry: () =>
                  context.read<ExamBloc>().add(ExamLoadRequested(bookId)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Intro View ──────────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  final ExamMetaLoaded state;
  final String bookTitle;

  const _IntroView({required this.state, required this.bookTitle});

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
    final s = state.settings;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          SheikhyPageHeader(
            title: 'الاختبار النهائي',
            showBack: true,
            height: 72,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                hs.AppSpacing.pageGutter,
                hs.AppSpacing.s6,
                hs.AppSpacing.pageGutter,
                hs.AppSpacing.s6 +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: hs.AppSpacing.s4),

                  // Title
                  Text(
                    'الاختبار النهائي',
                    style: GoogleFonts.arefRuqaa(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: hs.AppSpacing.s1),

                  // Book subtitle
                  Text(
                    bookTitle,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: hs.AppSpacing.s5),

                  // Info cards
                  _ExamInfoCard(
                    icon: Icons.format_list_numbered_outlined,
                    label: 'عدد الأسئلة',
                    value: _ar(state.questionCount),
                  ),
                  const SizedBox(height: hs.AppSpacing.s3),
                  _ExamInfoCard(
                    icon: Icons.timer_outlined,
                    label: 'الوقت المتاح',
                    value: '${_ar(s.timeLimitMinutes)} دقيقة',
                  ),
                  const SizedBox(height: hs.AppSpacing.s3),
                  _ExamInfoCard(
                    icon: Icons.trending_up_outlined,
                    label: 'نسبة النجاح',
                    value: '٪${_ar(s.passingPercentage)}',
                  ),
                  const SizedBox(height: hs.AppSpacing.s5),

                  // Lock notices
                  if (!state.settings.isPublished) ...[
                    SheikhyNotice(
                      variant: SheikhyNoticeVariant.danger,
                      message: 'الاختبار غير متاح حالياً',
                    ),
                    const SizedBox(height: hs.AppSpacing.s3),
                  ],
                  if (state.settings.isPublished && state.questionCount == 0) ...[
                    SheikhyNotice(
                      variant: SheikhyNoticeVariant.danger,
                      message: 'لا توجد أسئلة في الاختبار بعد',
                    ),
                    const SizedBox(height: hs.AppSpacing.s3),
                  ],
                  if (state.attemptsExhausted) ...[
                    SheikhyNotice(
                      variant: SheikhyNoticeVariant.danger,
                      message:
                          'لقد استنفدت جميع محاولاتك المسموحة (${_ar(s.maxAttempts)}/${_ar(s.maxAttempts)})',
                    ),
                    const SizedBox(height: hs.AppSpacing.s3),
                  ],

                  // Last attempt summary
                  if (state.pastAttempts.isNotEmpty &&
                      !state.attemptsExhausted) ...[
                    Text(
                      'آخر محاولة: ${_ar(state.pastAttempts.last.scorePercentage)}٪'
                      ' — ${state.pastAttempts.last.passed ? "ناجح ✓" : "راسب"}',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: hs.AppSpacing.s4),
                  ],

                  // Start button
                  SheikhyButton.primary(
                    fullWidth: true,
                    isLoading: state.isStarting,
                    onPressed: state.isLocked || state.isStarting
                        ? null
                        : () => context
                            .read<ExamBloc>()
                            .add(const ExamStartRequested()),
                    label: state.attemptsUsed == 0
                        ? 'ابدأ الاختبار الآن'
                        : 'إعادة الاختبار',
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),

                  // Past attempts link
                  if (state.pastAttempts.isNotEmpty) ...[
                    const SizedBox(height: hs.AppSpacing.s3),
                    Center(
                      child: SheikhyButton.text(
                        label: 'عرض محاولاتي السابقة',
                        onPressed: () => _showPastAttempts(context),
                      ),
                    ),
                  ],

                  const SizedBox(height: hs.AppSpacing.s5),

                  // Connectivity notice
                  SheikhyNotice(
                    variant: SheikhyNoticeVariant.info,
                    message:
                        'تأكد من اتصالك بالإنترنت قبل البدء، ولن تتمكن من إيقاف الاختبار بعد البدء. سيتم احتساب الدرجة بمجرد انتهاء الوقت أو تسليم الإجابات.',
                  ),
                ],
              ),
            ),
          ),
        ],
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

// ─── Exam info card (local, exam-intro-specific) ──────────────────────────────

class _ExamInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ExamInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: hs.AppSpacing.s5,
        vertical: hs.AppSpacing.s4,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.inkMuted),
          const SizedBox(width: hs.AppSpacing.s4),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              fontSize: 22,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Past attempts sheet ──────────────────────────────────────────────────────

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
                    passed ? AppColors.success : AppColors.danger;
                return Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: hs.AppSpacing.pageGutter,
                    vertical: hs.AppSpacing.s3,
                  ),
                  child: Row(
                    children: [
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
            padding: const EdgeInsetsDirectional.only(end: hs.AppSpacing.s4),
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
                padding: const EdgeInsets.all(hs.AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.questionText,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600, height: 1.5),
                    ),
                    const SizedBox(height: hs.AppSpacing.s4),
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
                hs.AppSpacing.s4,
                hs.AppSpacing.s2,
                hs.AppSpacing.s4,
                hs.AppSpacing.s4,
              ),
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

// ─── Exam not found ───────────────────────────────────────────────────────────

class ExamNotFoundView extends StatelessWidget {
  const ExamNotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: const [
          SheikhyPageHeader(title: 'الاختبار النهائي', showBack: true),
          Expanded(
            child: SheikhyEmptyState(
              icon: Icons.assignment_outlined,
              heading: 'الاختبار غير متاح',
              subtitle: 'لا يوجد اختبار نهائي لهذا الكتاب حالياً',
            ),
          ),
        ],
      ),
    );
  }
}
