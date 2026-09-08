// lib/features/lesson/view/lesson_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../lesson/data/lesson_repository.dart';
import '../../qa/cubit/qa_cubit.dart';
import '../../qa/data/qa_repository.dart';
import '../../qa/widgets/ask_question_sheet.dart';
import '../cubit/lesson_cubit.dart';
import '../cubit/lesson_state.dart';
import '../../../core/widgets/show_exam_start_dialog.dart';
import '../widgets/audio_tab.dart';
import '../widgets/pdf_tab.dart';
import '../widgets/quiz_tab.dart';
import '../widgets/video_tab.dart';

class LessonPage extends StatefulWidget {
  final String lessonId;
  final String bookId;

  const LessonPage({super.key, required this.lessonId, required this.bookId});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  @override
  void initState() {
    super.initState();
    context.read<LessonCubit>().loadLesson(widget.lessonId, widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LessonCubit, LessonState>(
      listenWhen: (prev, curr) {
        // Only auto-advance on a genuine in-session completion transition
        // (Loaded-incomplete → Loaded-complete). Opening an already-completed
        // lesson goes Loading → Loaded-complete, which must NOT auto-navigate.
        return prev is LessonLoaded &&
            !prev.isCompleted &&
            curr is LessonLoaded &&
            curr.isCompleted;
      },
      listener: (context, state) {
        if (state is! LessonLoaded) return;
        if (state.nextLessonId == null) return;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!context.mounted) return;
          context.pushReplacement(
            '/lessons/${state.nextLessonId}?bookId=${widget.bookId}',
          );
        });
      },
      builder: (context, state) {
        return switch (state) {
          LessonInitial() || LessonLoading() => _LessonSkeleton(
            lessonId: widget.lessonId,
            bookId: widget.bookId,
          ),
          LessonError(:final message) => _LessonErrorView(
            message: message,
            lessonId: widget.lessonId,
            bookId: widget.bookId,
          ),
          LessonLoaded() => _LessonView(
            state: state,
            lessonId: widget.lessonId,
            bookId: widget.bookId,
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LessonSkeleton extends StatelessWidget {
  final String lessonId;
  final String bookId;

  const _LessonSkeleton({required this.lessonId, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _LessonErrorView extends StatelessWidget {
  final String message;
  final String lessonId;
  final String bookId;

  const _LessonErrorView({
    required this.message,
    required this.lessonId,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          _MinimalLessonHeader(onBack: () => context.pop()),
          Expanded(
            child: SheikhyErrorState(
              heading: 'تعذّر تحميل الدرس',
              message: message,
              onRetry: () =>
                  context.read<LessonCubit>().loadLesson(lessonId, bookId),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact header for error / empty states ───────────────────────────────────

class _MinimalLessonHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _MinimalLessonHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: AppColors.primary,
                ),
                tooltip: 'رجوع',
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full loaded lesson view ───────────────────────────────────────────────────

class _LessonView extends StatefulWidget {
  final LessonLoaded state;
  final String lessonId;
  final String bookId;

  const _LessonView({
    required this.state,
    required this.lessonId,
    required this.bookId,
  });

  @override
  State<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<_LessonView> {
  bool _quizAnswering = false;

  void _onAnsweringChanged(bool answering) {
    if (_quizAnswering != answering) {
      setState(() => _quizAnswering = answering);
    }
  }

  Future<void> _handleBack() async {
    if (_quizAnswering) {
      final leave = await showLeaveQuizDialog(context);
      if (leave && mounted) context.pop();
    } else {
      context.pop();
    }
  }

  void _openAskSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => BlocProvider(
        create: (ctx) => AskQuestionCubit(ctx.read<QaRepository>()),
        child: AskQuestionSheet(
          bookId: widget.bookId,
          lessonId: widget.lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.state.lesson;
    final lessonRepo = context.read<LessonRepository>();
    // Always resume from the last saved position — a completed lesson can still
    // be re-watched from where the student left off. Tabs only seek when > 0.
    final resumeSeconds = widget.state.lastPositionSeconds;

    final tabs = <_TabDef>[
      if (lesson.hasVideo)
        _TabDef(
          label: 'فيديو',
          icon: Icons.play_circle_outline,
          completionLabel: 'أكملت الفيديو',
          isVideoTab: true,
          content: VideoTab(
            videoUrl: lesson.videoUrl!,
            initialPositionSeconds: resumeSeconds,
          ),
        ),
      if (lesson.hasAudio)
        _TabDef(
          label: 'صوت',
          icon: Icons.headphones_outlined,
          completionLabel: 'أكملت الصوت',
          content: AudioTab(
            audioUrl: lesson.audioUrl!,
            lessonTitle: lesson.title,
            initialPositionSeconds: resumeSeconds,
          ),
        ),
      if (lesson.hasPdf)
        _TabDef(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          completionLabel: 'أكملت القراءة',
          content: PdfTab(pdfUrl: lesson.pdfUrl!),
        ),
      // Tab VISIBILITY keys off presence (lessonHasQuiz), so guests / unenrolled
      // on a lesson that genuinely has a quiz still see the tab — gated. Lessons
      // with no quiz keep hiding it.
      if (widget.state.lessonHasQuiz)
        _TabDef(
          label: 'اختبار',
          icon: Icons.quiz_outlined,
          completionLabel: null,
          content: widget.state.canTakeQuiz
              ? RepositoryProvider.value(
                  value: lessonRepo,
                  child: QuizTab(
                    lessonId: widget.lessonId,
                    onAnsweringChanged: _onAnsweringChanged,
                  ),
                )
              : _QuizGate(bookId: widget.bookId, lessonId: widget.lessonId),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _LessonHeader(
              state: widget.state,
              onAskTap: () => _openAskSheet(context),
              onBack: _handleBack,
            ),
            Expanded(
              child: SheikhyEmptyState(
                icon: Icons.layers_outlined,
                heading: 'لا يوجد محتوى',
                subtitle: 'لم يُضَف محتوى لهذا الدرس بعد',
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_quizAnswering,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showLeaveQuizDialog(context);
        if (leave && context.mounted) context.pop();
      },
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: Column(
            children: [
              _LessonHeader(
                state: widget.state,
                onAskTap: () => _openAskSheet(context),
                onBack: _handleBack,
              ),
              _LessonTabBar(tabs: tabs),
              Expanded(
                child: TabBarView(
                  children: tabs.map((t) => t.content).toList(),
                ),
              ),
              _LessonActionBar(
                tabs: tabs,
                state: widget.state,
                bookId: widget.bookId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paper-colored header ──────────────────────────────────────────────────────

class _LessonHeader extends StatelessWidget {
  final LessonLoaded state;
  final VoidCallback onAskTap;
  final VoidCallback onBack;

  const _LessonHeader({
    required this.state,
    required this.onAskTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = state.lesson;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.pageGutter,
            AppSpacing.s2,
            AppSpacing.s2,
            AppSpacing.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lesson number + title (start side = right in RTL)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الدرس ${lesson.orderIndex}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      lesson.title,
                      style: GoogleFonts.reemKufi(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              // End-side icons column (left in RTL)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'رجوع',
                    onPressed: onBack,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.menu_book_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    tooltip: 'اسأل سؤالك',
                    onPressed: onAskTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Heritage tab bar ──────────────────────────────────────────────────────────

class _LessonTabBar extends StatelessWidget {
  final List<_TabDef> tabs;

  const _LessonTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
      ),
      child: TabBar(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          insets: EdgeInsets.zero,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkFaint,
        labelStyle: GoogleFonts.reemKufi(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: tabs
            .map((t) => Tab(icon: Icon(t.icon, size: 20), text: t.label))
            .toList(),
      ),
    );
  }
}

// ── Tab-aware action bar ──────────────────────────────────────────────────────

class _LessonActionBar extends StatefulWidget {
  final List<_TabDef> tabs;
  final LessonLoaded state;
  final String bookId;

  const _LessonActionBar({
    required this.tabs,
    required this.state,
    required this.bookId,
  });

  @override
  State<_LessonActionBar> createState() => _LessonActionBarState();
}

class _LessonActionBarState extends State<_LessonActionBar> {
  TabController? _tabController;
  int _activeIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (controller != null && _tabController != controller) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = controller;
      _tabController!.addListener(_onTabChanged);
      _activeIndex = controller.index;
    }
  }

  void _onTabChanged() {
    if (mounted && _tabController != null) {
      setState(() => _activeIndex = _tabController!.index);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  _TabDef? get _activeTab =>
      _activeIndex < widget.tabs.length ? widget.tabs[_activeIndex] : null;

  bool get _isQuizTab => _activeTab?.completionLabel == null;
  bool get _isVideoTab => _activeTab?.isVideoTab == true;

  @override
  Widget build(BuildContext context) {
    if (_isQuizTab) return const SizedBox.shrink();

    final state = widget.state;

    final String label;
    final VoidCallback? onPressed;
    final Widget? icon;

    if (_isVideoTab) {
      // 3-state video button
      if (state.quizAttempted ||
          state.quizExhausted ||
          (!state.hasQuizQuestions && state.videoWatched) ||
          state.isCompleted) {
        // State 3 — quiz done (or no quiz and video watched)
        if (state.nextLessonId != null) {
          label = 'الدرس التالي';
          icon = null;
          onPressed = () => context.pushReplacement(
            '/lessons/${state.nextLessonId}?bookId=${widget.bookId}',
          );
        } else {
          label = 'مكتمل ✓';
          icon = const Icon(Icons.check);
          onPressed = null;
        }
      } else if (state.videoWatched && state.hasQuizQuestions) {
        // State 2 — video watched, quiz pending
        label = 'ابدأ الاختبار';
        icon = null;
        onPressed = () {
          final quizIndex = widget.tabs.indexWhere(
            (t) => t.completionLabel == null,
          );
          if (quizIndex >= 0) _tabController?.animateTo(quizIndex);
        };
      } else {
        // State 1 — video not yet marked watched
        label = 'أنهيت المحاضرة';
        icon = null;
        onPressed = () => context.read<LessonCubit>().markVideoWatched();
      }
    } else {
      // Non-video, non-quiz tabs — existing behavior
      icon = state.isCompleted && state.nextLessonId == null
          ? const Icon(Icons.check)
          : null;
      if (state.isCompleted) {
        if (state.nextLessonId != null) {
          label = 'الدرس التالي';
          onPressed = () => context.pushReplacement(
            '/lessons/${state.nextLessonId}?bookId=${widget.bookId}',
          );
        } else {
          label = 'مكتمل ✓';
          onPressed = null;
        }
      } else {
        label = _activeTab?.completionLabel ?? 'حفظ الدرس';
        onPressed = () => context.read<LessonCubit>().markVideoWatched();
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppBorders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.pageGutter,
            AppSpacing.s3,
            AppSpacing.pageGutter,
            AppSpacing.s4,
          ),
          child: SheikhyButton.primary(
            label: label,
            icon: icon,
            fullWidth: true,
            isLoading: state.isSavingProgress,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

// ── Tab definition ────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final IconData icon;
  final String? completionLabel;
  final Widget content;
  final bool isVideoTab;

  const _TabDef({
    required this.label,
    required this.icon,
    required this.completionLabel,
    required this.content,
    this.isVideoTab = false,
  });
}

// ── Quiz gate (guest / registered-not-enrolled) ───────────────────────────────
//
// Shown as the quiz tab's content when the session isn't entitled to take the
// quiz. The tab itself stays visible (lessonHasQuiz) so the quiz is discoverable;
// tapping it reveals this gate instead of loading any content — so no quiz rows
// are ever fetched for a guest. Basic dialog-free panel for now; Stage 3 replaces
// it with the shared AccountGate component.
class _QuizGate extends StatelessWidget {
  final String bookId;
  final String lessonId;

  const _QuizGate({required this.bookId, required this.lessonId});

  bool _isGuest(BuildContext context) {
    final s = context.read<AuthCubit>().state;
    return s is AuthAuthenticated && s.isGuest;
  }

  void _onCta(BuildContext context) {
    if (_isGuest(context)) {
      // Convert in place, then return to this lesson auto-enrolled.
      final signupLoc = Uri(
        path: '/signup',
        queryParameters: {
          'returnTo': '/lessons/$lessonId?bookId=$bookId',
          'autoEnrollBookId': bookId,
        },
      ).toString();
      context.push(signupLoc);
    } else {
      // Registered but not enrolled → back to book details to enroll.
      context.go('/books/$bookId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = _isGuest(context);
    final message = guest
        ? 'سجّل حساباً أولاً عشان تقدر تحل الاختبار'
        : 'سجّل في الكتاب أولاً عشان تقدر تحل الاختبار';
    final ctaLabel = guest ? 'أنشئ حساباً' : 'التسجيل في الكتاب';
    final ctaIcon = guest
        ? Icons.person_add_alt_1_outlined
        : Icons.how_to_reg_outlined;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.goldSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.lock_outline,
                color: AppColors.goldDeep,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'الاختبار غير متاح الآن',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s5),
            SheikhyButton.primary(
              label: ctaLabel,
              icon: Icon(ctaIcon),
              onPressed: () => _onCta(context),
            ),
          ],
        ),
      ),
    );
  }
}
