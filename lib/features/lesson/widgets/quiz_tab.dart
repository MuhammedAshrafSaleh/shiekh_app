// lib/features/lesson/widgets/quiz_tab.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/audio/app_sound.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/mcq_option_card.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/show_exam_start_dialog.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_labeled_divider.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../features/lesson/cubit/lesson_cubit.dart';
import '../../../features/lesson/cubit/lesson_state.dart';
import '../../../features/lesson/data/lesson_repository.dart';
import '../../../models/lesson_quiz_attempt_entity.dart';

const int _kLessonQuizDurationSeconds = 900; // 15 minutes

enum _QuizPhase { intro, loading, error, answering, submitted, review }

enum _ReviewOrigin { result, intro }

class QuizTab extends StatefulWidget {
  final String lessonId;

  /// When true, grading still runs (read-only) but no attempt is recorded via
  /// LessonCubit — used by the admin "preview as student" screen.
  final bool previewMode;

  /// Called with true when the user enters the answering phase, false when they
  /// leave it. Used by the parent to intercept back-navigation.
  final void Function(bool answering)? onAnsweringChanged;

  const QuizTab({
    super.key,
    required this.lessonId,
    this.previewMode = false,
    this.onAnsweringChanged,
  });

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> with AutomaticKeepAliveClientMixin {
  _QuizPhase _phase = _QuizPhase.intro;
  _ReviewOrigin _reviewOrigin = _ReviewOrigin.result;

  List<dynamic> _questions = [];
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  QuizGradeResult? _result;
  String? _errorMessage;

  List<QuizReviewQuestion> _reviewQuestions = [];

  Timer? _quizTimer;
  DateTime? _quizEndAt;

  @override
  bool get wantKeepAlive => _phase == _QuizPhase.answering;

  @override
  void initState() {
    super.initState();
    _preloadQuestions();
  }

  /// Single entry-point for all phase transitions so `onAnsweringChanged` is
  /// always fired consistently. [also] runs inside the same setState call.
  void _gotoPhase(_QuizPhase newPhase, [VoidCallback? also]) {
    setState(() {
      _phase = newPhase;
      also?.call();
    });
    widget.onAnsweringChanged?.call(newPhase == _QuizPhase.answering);
    updateKeepAlive();
  }

  @override
  void dispose() {
    _cancelQuizTimer();
    // Ensure the parent is notified that we are no longer in answering phase
    // if the widget is removed (e.g., tab changed, page popped).
    if (_phase == _QuizPhase.answering) {
      widget.onAnsweringChanged?.call(false);
    }
    super.dispose();
  }

  void _startQuizTimer() {
    _quizEndAt = DateTime.now().add(
      const Duration(seconds: _kLessonQuizDurationSeconds),
    );
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _quizEndAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _cancelQuizTimer();
        setState(() {}); // show 00:00 before submit
        _submit();
      } else {
        if (remaining <= 10) {
          context.read<SoundService>().play(AppSound.tickUrgent);
        } else if (remaining <= 60) {
          context.read<SoundService>().play(AppSound.tick);
        }
        setState(() {});
      }
    });
  }

  void _cancelQuizTimer() {
    _quizTimer?.cancel();
    _quizTimer = null;
  }

  Future<void> _preloadQuestions() async {
    final repo = context.read<LessonRepository>();
    final result = await repo.getQuizQuestions(widget.lessonId);
    if (!mounted) return;
    result.fold((_) {}, (q) => setState(() => _questions = q));
  }

  Future<void> _startQuiz() async {
    if (_questions.isEmpty) {
      _gotoPhase(_QuizPhase.loading);
      final repo = context.read<LessonRepository>();
      final result = await repo.getQuizQuestions(widget.lessonId);
      if (!mounted) return;
      result.fold(
        (failure) => _gotoPhase(_QuizPhase.error, () {
          _errorMessage = failure.message;
        }),
        (questions) {
          _gotoPhase(_QuizPhase.answering, () {
            _questions = questions;
            _currentIndex = 0;
            _answers.clear();
          });
          _startQuizTimer();
        },
      );
    } else {
      _gotoPhase(_QuizPhase.answering, () {
        _currentIndex = 0;
        _answers.clear();
      });
      _startQuizTimer();
    }
  }

  Future<void> _submit() async {
    _cancelQuizTimer();
    _gotoPhase(_QuizPhase.loading);
    final repo = context.read<LessonRepository>();

    final result = widget.previewMode
        ? await repo.gradeQuiz(widget.lessonId, _answers)
        : await repo.submitQuiz(widget.lessonId, _answers);

    result.fold(
      (failure) {
        if (mounted) {
          _gotoPhase(_QuizPhase.error, () => _errorMessage = failure.message);
        }
      },
      (grade) {
        if (mounted) {
          _gotoPhase(_QuizPhase.submitted, () => _result = grade);
          // Result sound — reuse the same pass rule as _QuizResult
          // (percentage >= 60). Fire-and-forget: not awaited, so it never
          // delays the result UI.
          final passed = grade.percentage >= 60;
          context.read<SoundService>().play(
            passed ? AppSound.success : AppSound.retry,
          );
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
            context.read<LessonCubit>().markQuizAttempted(
              grade.attemptsUsed,
              newAttempt,
            );
          }
        }
      },
    );
  }

  Future<void> _loadReview(int? attemptNumber, _ReviewOrigin origin) async {
    _gotoPhase(_QuizPhase.loading);
    final repo = context.read<LessonRepository>();
    final result = await repo.getQuizReview(
      widget.lessonId,
      attemptNumber: attemptNumber,
    );
    if (!mounted) return;
    result.fold(
      (failure) => _gotoPhase(_QuizPhase.error, () {
        _errorMessage = failure.message;
      }),
      (questions) => _gotoPhase(_QuizPhase.review, () {
        _reviewQuestions = questions;
        _reviewOrigin = origin;
      }),
    );
  }

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    if (_phase == _QuizPhase.loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_phase == _QuizPhase.error) {
      return SheikhyErrorState(
        heading: 'تعذّر تحميل الاختبار',
        message: _errorMessage ?? 'حدث خطأ غير متوقع',
        onRetry: () => _gotoPhase(_QuizPhase.intro),
      );
    }

    if (_phase == _QuizPhase.review) {
      return _QuizReview(
        questions: _reviewQuestions,
        onBack: () => _gotoPhase(
          _reviewOrigin == _ReviewOrigin.result
              ? _QuizPhase.submitted
              : _QuizPhase.intro,
        ),
      );
    }

    if (_phase == _QuizPhase.intro) {
      if (widget.previewMode) {
        return _QuizIntro(
          questionCount: _questions.length,
          attemptsUsed: 0,
          pastAttempts: const [],
          onStart: _startQuiz,
          onReview: (n) => _loadReview(n, _ReviewOrigin.intro),
        );
      }
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
      return const SheikhyEmptyState(
        icon: Icons.quiz_outlined,
        heading: 'لا توجد أسئلة',
        subtitle: 'لم تُضَف أسئلة لهذا الدرس بعد',
      );
    }

    if (_phase == _QuizPhase.submitted && _result != null) {
      return _QuizResult(
        result: _result!,
        ar: _ar,
        onRetry: () => _gotoPhase(_QuizPhase.intro),
        onReview: () => _loadReview(null, _ReviewOrigin.result),
      );
    }

    // ── Answering phase ──────────────────────────────────────────────────────
    final question = _questions[_currentIndex];
    final total = _questions.length;
    final isLast = _currentIndex == total - 1;
    final secondsRemaining = _quizEndAt == null
        ? _kLessonQuizDurationSeconds
        : max(0, _quizEndAt!.difference(DateTime.now()).inSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question bar
        _QuizBar(
          currentIndex: _currentIndex,
          total: total,
          ar: _ar,
          secondsRemaining: secondsRemaining,
        ),
        const Divider(height: 1, color: AppColors.border),

        // Scrollable question + options
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
                  question.questionText,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                for (final choice in ['a', 'b', 'c', 'd'])
                  McqOptionCard(
                    label: _choiceLabel(choice),
                    text: question.choiceLabel(choice),
                    optionState: _answers[question.id] == choice
                        ? McqOptionState.selected
                        : McqOptionState.idle,
                    onTap: () => setState(() => _answers[question.id] = choice),
                  ),
              ],
            ),
          ),
        ),

        // Bottom navigation
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s2,
              AppSpacing.pageGutter,
              AppSpacing.s4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SheikhyButton.secondary(
                    fullWidth: true,
                    label: 'السابق',
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: _currentIndex > 0
                        ? () => setState(() => _currentIndex--)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: isLast
                      ? SheikhyButton.primary(
                          fullWidth: true,
                          label: 'تسليم الاختبار',
                          icon: const Icon(Icons.check_rounded, size: 16),
                          onPressed: _answers.length < total
                              ? _showUnansweredWarning
                              : _submit,
                        )
                      : SheikhyButton.primary(
                          fullWidth: true,
                          label: 'التالي',
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          onPressed: () => setState(() => _currentIndex++),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageGutter,
          vertical: AppSpacing.s8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dangerBg,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 28,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'أسئلة غير مجاب عليها',
                style: AppTextStyles.h3.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'لديك ${_QuizTabState._ar(unanswered)} سؤال لم تجب عليه. الأسئلة المتبقية ستُعتبر خاطئة.',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s5),
              SheikhyButton.primary(
                fullWidth: true,
                label: 'تسليم على أي حال',
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _submit();
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              SheikhyButton.secondary(
                fullWidth: true,
                label: 'مراجعة الأسئلة',
                icon: const Icon(Icons.list_rounded),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question bar ─────────────────────────────────────────────────────────────

class _QuizBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final String Function(int) ar;
  final int secondsRemaining;

  const _QuizBar({
    required this.currentIndex,
    required this.total,
    required this.ar,
    required this.secondsRemaining,
  });

  static String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsRemaining <= 60;
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s4,
            ),
            child: Row(
              children: [
                // Question counter (start / right in RTL)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سؤال ${ar(currentIndex + 1)} من',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkMuted,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      ar(total),
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Countdown timer (end / left in RTL)
                Text(
                  _formatTime(secondsRemaining),
                  style: AppTextStyles.small.copyWith(
                    color: isUrgent ? AppColors.danger : AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Intro phase ──────────────────────────────────────────────────────────────

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

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final exhausted = attemptsUsed >= 2;
    final attemptsRemaining = 2 - attemptsUsed;

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s5,
        AppSpacing.pageGutter,
        AppSpacing.s6 + context.safeBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.quiz_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Title
          Text(
            'اختبار الدرس',
            style: GoogleFonts.arefRuqaa(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),

          // Info cards
          _IntroInfoCard(
            icon: Icons.format_list_numbered_outlined,
            label: 'عدد الأسئلة',
            value: '${_ar(questionCount)} سؤال',
          ),
          const SizedBox(height: AppSpacing.s3),
          _IntroInfoCard(
            icon: Icons.repeat_rounded,
            label: 'المحاولات المتبقية',
            value: '${_ar(attemptsRemaining)} من ${_ar(2)}',
            valueColor: attemptsRemaining == 0
                ? AppColors.danger
                : attemptsRemaining == 1
                ? AppColors.warning
                : AppColors.success,
          ),

          // Past attempts
          if (pastAttempts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s5),
            const SheikhyLabeledDivider(label: 'المحاولات السابقة'),
            const SizedBox(height: AppSpacing.s3),
            for (final attempt in pastAttempts)
              _AttemptCard(
                attempt: attempt,
                ar: _ar,
                onReview: () => onReview(attempt.attemptNumber),
              ),
          ],

          const SizedBox(height: AppSpacing.s5),

          if (exhausted) ...[
            SheikhyNotice(
              variant: SheikhyNoticeVariant.danger,
              message: 'لقد استنفدت جميع المحاولات المسموحة',
            ),
            const SizedBox(height: AppSpacing.s3),
            SheikhyButton.secondary(
              fullWidth: true,
              label: 'مراجعة آخر محاولة',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: pastAttempts.isNotEmpty
                  ? () => onReview(pastAttempts.last.attemptNumber)
                  : null,
            ),
          ] else ...[
            Text(
              'أجب على جميع الأسئلة ثم اضغط تسليم',
              style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            SheikhyButton.primary(
              fullWidth: true,
              label: attemptsUsed > 0 ? 'إعادة الاختبار' : 'ابدأ الاختبار',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () async {
                final confirmed = await showExamStartDialog(context);
                if (confirmed) onStart();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _IntroInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s5,
        vertical: AppSpacing.s4,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.small.copyWith(
              color: valueColor ?? AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final LessonQuizAttemptEntity attempt;
  final String Function(int) ar;
  final VoidCallback onReview;

  const _AttemptCard({
    required this.attempt,
    required this.ar,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final passed = attempt.passed;
    final accentColor = passed ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.s3),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              ar(attempt.attemptNumber),
              style: AppTextStyles.small.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'المحاولة ${ar(attempt.attemptNumber)}',
              style: AppTextStyles.small.copyWith(color: AppColors.ink),
            ),
          ),
          Text(
            '${ar(attempt.scorePercentage)}٪',
            style: AppTextStyles.small.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          SheikhyButton.text(label: 'مراجعة', onPressed: onReview),
        ],
      ),
    );
  }
}

// ─── Result phase ─────────────────────────────────────────────────────────────

class _QuizResult extends StatelessWidget {
  final QuizGradeResult result;
  final String Function(int) ar;
  final VoidCallback onRetry;
  final VoidCallback onReview;

  const _QuizResult({
    required this.result,
    required this.ar,
    required this.onRetry,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final passed = result.percentage >= 60;
    final canRetry = result.attemptsUsed < 2;
    final ringColor = passed ? AppColors.primary : AppColors.danger;

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s6,
        AppSpacing.pageGutter,
        AppSpacing.s6 + context.safeBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score ring
          Center(
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 9),
                color: AppColors.paper,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '٪${ar(result.percentage)}',
                    style: GoogleFonts.arefRuqaa(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'النتيجة',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),

          // Heading
          Text(
            passed ? 'أحسنت! لقد نجحت' : 'راجع الدرس وحاول مجدداً',
            style: GoogleFonts.arefRuqaa(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s3),

          // Score pill
          Center(
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s5,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.rPill,
                border: Border.all(
                  color: AppColors.border,
                  width: AppBorders.hairline,
                ),
              ),
              child: Text(
                '${ar(result.correct)} من ${ar(result.total)} إجابة صحيحة',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),

          // Attempt counter
          Text(
            'المحاولة ${ar(result.attemptsUsed)} من ${ar(2)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),

          // Review button
          SheikhyButton.secondary(
            fullWidth: true,
            label: 'مراجعة الإجابات',
            icon: const Icon(Icons.checklist_rounded),
            onPressed: onReview,
          ),
          const SizedBox(height: AppSpacing.s3),

          // Retry or exhausted notice
          if (canRetry)
            SheikhyButton.primary(
              fullWidth: true,
              label: 'إعادة الاختبار',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRetry,
            )
          else
            SheikhyNotice(
              variant: SheikhyNoticeVariant.danger,
              message: 'لقد استنفدت جميع المحاولات المسموحة',
            ),
        ],
      ),
    );
  }
}

// ─── Review phase ─────────────────────────────────────────────────────────────

class _QuizReview extends StatelessWidget {
  final List<QuizReviewQuestion> questions;
  final VoidCallback onBack;

  const _QuizReview({required this.questions, required this.onBack});

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back header
        Container(
          color: AppColors.surface,
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
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      tooltip: 'رجوع',
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      'مراجعة الإجابات',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Question list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s4,
              AppSpacing.pageGutter,
              AppSpacing.s6 + context.safeBottom,
            ),
            itemCount: questions.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Divider(height: 1, color: AppColors.border),
            ),
            itemBuilder: (context, index) => _ReviewQuestionCard(
              index: index,
              question: questions[index],
              ar: _ar,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final QuizReviewQuestion question;
  final String Function(int) ar;

  const _ReviewQuestionCard({
    required this.index,
    required this.question,
    required this.ar,
  });

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.paperSunk,
                border: Border.all(
                  color: AppColors.border,
                  width: AppBorders.hairline,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                ar(index + 1),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                question.questionText,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (question.userAnswer == null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            'لم تتم الإجابة على هذا السؤال',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        for (final choice in ['a', 'b', 'c', 'd'])
          McqOptionCard(
            label: _choiceLabel(choice),
            text: question.choiceText(choice),
            optionState: _stateFor(choice),
            onTap: null,
          ),
      ],
    );
  }
}
