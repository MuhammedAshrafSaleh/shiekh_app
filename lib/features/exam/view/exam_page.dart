// lib/features/exam/view/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/app_messenger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart' as hs;
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/show_exam_start_dialog.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../models/final_exam_attempt_entity.dart';
import '../bloc/exam_bloc.dart';
import '../bloc/exam_event.dart';
import '../bloc/exam_state.dart';
import '../data/exam_repository.dart';
import '../widgets/exam_navigator_grid.dart';
import '../widgets/timer_display.dart';
import 'exam_review_page.dart';

class ExamPage extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const ExamPage({super.key, required this.bookId, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamBloc, ExamState>(
      listener: (context, state) {
        if (state is ExamCompleted) {
          context.go('/books/$bookId/exam/result', extra: state);
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
          ExamInitial() ||
          ExamLoading() => _LoadingScaffold(bookTitle: bookTitle),
          ExamGated() => _GatedScaffold(bookId: bookId, bookTitle: bookTitle),
          ExamMetaLoaded() => _IntroView(state: state, bookTitle: bookTitle),
          ExamInProgress() => _InProgressView(
            state: state,
            bookTitle: bookTitle,
          ),
          ExamCompleted() => Scaffold(
            backgroundColor: AppColors.paper,
            body: const Center(child: CircularProgressIndicator()),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

// ─── Gated (not enrolled) ─────────────────────────────────────────────────────

class _GatedScaffold extends StatelessWidget {
  final String bookId;
  final String bookTitle;
  const _GatedScaffold({required this.bookId, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheikhyPageHeader(title: bookTitle, showBack: true),
          Expanded(
            child: AccountGate(
              reason: GateReason.enrollment,
              bookId: bookId,
              returnTo: '/books/$bookId/exam',
              title: 'الاختبار النهائي غير متاح',
              guestMessage: 'أنشئ حساباً وسجّل في الكتاب لأداء الاختبار النهائي.',
              enrolledMessage: 'سجّل في الكتاب أولاً لأداء الاختبار النهائي.',
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheikhyPageHeader(title: 'الاختبار النهائي', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                hs.AppSpacing.pageGutter,
                hs.AppSpacing.s6,
                hs.AppSpacing.pageGutter,
                hs.AppSpacing.s6 + MediaQuery.viewPaddingOf(context).bottom,
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
                  if (state.settings.isPublished &&
                      state.questionCount == 0) ...[
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'آخر محاولة: ${_ar(state.pastAttempts.last.scorePercentage)}٪'
                          ' — ${state.pastAttempts.last.passed ? "ناجح ✓" : "راسب"}',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final last = state.pastAttempts.last;
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExamReviewPage(
                                  bookId: state.bookId,
                                  attemptId: last.id,
                                  attemptNumber: last.attemptNumber,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsetsDirectional.only(
                              start: hs.AppSpacing.s2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'مراجعة',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: hs.AppSpacing.s4),
                  ],

                  // Start button
                  SheikhyButton.primary(
                    fullWidth: true,
                    isLoading: state.isStarting,
                    onPressed: state.isLocked || state.isStarting
                        ? null
                        : () async {
                            final confirmed = await showExamStartDialog(
                              context,
                            );
                            if (confirmed && context.mounted) {
                              context.read<ExamBloc>().add(
                                const ExamStartRequested(),
                              );
                            }
                          },
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
    final repo = context.read<ExamRepository>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => _PastAttemptsSheet(
        attempts: state.pastAttempts,
        bookId: state.bookId,
        repository: repo,
      ),
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
  final String bookId;
  final ExamRepository repository;
  const _PastAttemptsSheet({
    required this.attempts,
    required this.bookId,
    required this.repository,
  });

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
                Text('المحاولات السابقة', style: AppTextStyles.h3),
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
                final accentColor = passed
                    ? AppColors.success
                    : AppColors.danger;
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            passed ? Icons.check_circle : Icons.cancel,
                            color: accentColor,
                            size: 22,
                          ),
                          const SizedBox(width: hs.AppSpacing.s2),
                          TextButton(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamReviewPage(
                                    bookId: bookId,
                                    attemptId: a.id,
                                    attemptNumber: a.attemptNumber,
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'مراجعة',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

// ─── Question bar (heritage top-bar for the in-progress view) ────────────────
//
// Paper background, hairline bottom border.
// Start (right in RTL): back arrow + "سؤال X من Y" counter.
// End  (left  in RTL): live timer chip via BlocSelector.

class _QuestionBar extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;

  const _QuestionBar({
    required this.currentIndex,
    required this.totalQuestions,
  });

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
              horizontal: hs.AppSpacing.s2,
            ),
            child: Row(
              children: [
                // Start (right in RTL): back arrow + question counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      tooltip: 'رجوع',
                      onPressed: () => _showLeaveExamDialog(context),
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
                  ],
                ),

                const Spacer(),

                // End (left in RTL): live timer
                BlocSelector<ExamBloc, ExamState, int>(
                  selector: (s) => s is ExamInProgress ? s.secondsRemaining : 0,
                  builder: (_, secs) => TimerDisplay(secondsRemaining: secs),
                ),
                const SizedBox(width: hs.AppSpacing.s2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── In-Progress View ─────────────────────────────────────────────────────────

void _showBackgroundWarningDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تحذير'),
      content: const Text(
        'تم رصد خروجك من التطبيق. لو خرجت تاني هيتم تسليم الامتحان تلقائياً.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

void _showLeaveExamDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تأكيد الخروج'),
      content: const Text(
        'لو خرجت من الامتحان هيتم تسليمه بإجاباتك الحالية، وهتتحسب محاولة مستخدمة ومش هتقدر ترجّعها. متأكد؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('كمّل الامتحان'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.read<ExamBloc>().add(const ExamSubmitConfirmed());
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('سلّم واخرج'),
        ),
      ],
    ),
  );
}

class _InProgressView extends StatefulWidget {
  final ExamInProgress state;
  final String bookTitle;

  const _InProgressView({required this.state, required this.bookTitle});

  @override
  State<_InProgressView> createState() => _InProgressViewState();
}

class _InProgressViewState extends State<_InProgressView> {
  late final ExamBloc _bloc;
  late final AppLifecycleListener _lifecycleListener;
  bool _isAway = false;

  void _markAway() {
    if (!_isAway) _isAway = true;
  }

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ExamBloc>();
    _lifecycleListener = AppLifecycleListener(
      onPause: _markAway,
      onHide: _markAway,
      onResume: () {
        if (!_isAway) return;
        _isAway = false;
        _bloc.add(const ExamBackgroundLeave());
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final q = state.currentQuestion;
    final selectedChoice = state.answers[q.id];

    return BlocListener<ExamBloc, ExamState>(
      listenWhen: (prev, curr) =>
          prev is ExamInProgress &&
          curr is ExamInProgress &&
          prev.backgroundLeaveCount != curr.backgroundLeaveCount,
      listener: (context, curr) {
        final s = curr as ExamInProgress;
        if (s.backgroundLeaveCount == 1) {
          _showBackgroundWarningDialog(context);
        } else if (s.backgroundLeaveCount == ExamInProgress.backgroundLeaveLimit) {
          appMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: const Text('تم تسليم الامتحان لأنك خرجت من التطبيق'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _showLeaveExamDialog(context);
        },
        child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Heritage question bar (replaces Material AppBar)
            _QuestionBar(
              currentIndex: state.currentIndex,
              totalQuestions: state.questions.length,
            ),

            // Question + choices + navigator
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  hs.AppSpacing.pageGutter,
                  hs.AppSpacing.s4,
                  hs.AppSpacing.pageGutter,
                  hs.AppSpacing.s4,
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
                    const SizedBox(height: hs.AppSpacing.s2),
                    ExamNavigatorGrid(
                      questions: state.questions,
                      answers: state.answers,
                      currentIndex: state.currentIndex,
                      onNavigate: (i) =>
                          context.read<ExamBloc>().add(ExamNavigateTo(i)),
                    ),
                  ],
                ),
              ),
            ),

            // Prev / Next / Submit
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  hs.AppSpacing.pageGutter,
                  hs.AppSpacing.s2,
                  hs.AppSpacing.pageGutter,
                  hs.AppSpacing.s4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SheikhyButton.secondary(
                        fullWidth: true,
                        label: 'السابق',
                        onPressed: state.currentIndex > 0 && !state.isSubmitting
                            ? () => context.read<ExamBloc>().add(
                                ExamNavigateTo(state.currentIndex - 1),
                              )
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                    const SizedBox(width: hs.AppSpacing.s3),
                    Expanded(
                      child: state.currentIndex < state.questions.length - 1
                          ? SheikhyButton.primary(
                              fullWidth: true,
                              label: 'التالي',
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => context.read<ExamBloc>().add(
                                      ExamNavigateTo(state.currentIndex + 1),
                                    ),
                              icon: const Icon(Icons.arrow_back_ios, size: 16),
                            )
                          : SheikhyButton.primary(
                              fullWidth: true,
                              isLoading: state.isSubmitting,
                              label: 'تسليم',
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => _confirmSubmit(context),
                              icon: const Icon(Icons.send_rounded, size: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _confirmSubmit(BuildContext context) {
    final unanswered = widget.state.unansweredCount;
    final answered = widget.state.answeredCount;
    final total = widget.state.questions.length;
    final hasUnanswered = unanswered > 0;

    String ar(int n) {
      const w = '0123456789';
      const a = '٠١٢٣٤٥٦٧٨٩';
      return n.toString().split('').map((c) {
        final i = w.indexOf(c);
        return i >= 0 ? a[i] : c;
      }).join();
    }

    showDialog<void>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: hs.AppSpacing.pageGutter,
          vertical: hs.AppSpacing.s8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(hs.AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasUnanswered
                        ? AppColors.dangerBg
                        : AppColors.primaryTint,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    hasUnanswered
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 28,
                    color: hasUnanswered ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: hs.AppSpacing.s4),

              // Title
              Text(
                'هل أنت متأكد من إنهاء الاختبار؟',
                style: AppTextStyles.h3.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: hs.AppSpacing.s3),

              // Body
              Text(
                hasUnanswered
                    ? 'لقد أجبت على ${ar(answered)} من ${ar(total)} سؤال، الأسئلة المتبقية ستُعتبر خاطئة.'
                    : 'لقد أجبت على جميع الأسئلة. هل تريد تسليم الاختبار الآن؟',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: hs.AppSpacing.s5),

              // Submit
              SheikhyButton.primary(
                fullWidth: true,
                label: 'تسليم الاختبار',
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: () {
                  ctx.pop();
                  context.read<ExamBloc>().add(const ExamSubmitConfirmed());
                },
              ),
              const SizedBox(height: hs.AppSpacing.s3),

              // Review (dismiss)
              SheikhyButton.secondary(
                fullWidth: true,
                label: 'مراجعة الأسئلة',
                icon: const Icon(Icons.list_rounded),
                onPressed: () => ctx.pop(),
              ),
            ],
          ),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
