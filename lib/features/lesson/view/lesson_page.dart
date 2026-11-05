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
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../notes/cubit/notes_cubit.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/data/notes_source.dart';
import '../../lesson/data/lesson_repository.dart';
import '../../qa/cubit/qa_cubit.dart';
import '../../qa/data/qa_repository.dart';
import '../../qa/widgets/ask_question_sheet.dart';
import '../cubit/lesson_cubit.dart';
import '../cubit/lesson_state.dart';
import '../../../core/widgets/show_exam_start_dialog.dart';
import '../widgets/audio_tab.dart';
import '../widgets/media_tab.dart';
import '../widgets/pdf_list_tab.dart';
import '../widgets/pdf_tab.dart';
import '../widgets/quiz_tab.dart';
import '../widgets/video_tab.dart';

class LessonPage extends StatefulWidget {
  final String lessonId;
  final String bookId;

  /// When non-null, the video tab seeks to this position on open (from `?t=`).
  /// Takes precedence over the saved resume position.
  final int? seekToSeconds;

  const LessonPage({
    super.key,
    required this.lessonId,
    required this.bookId,
    this.seekToSeconds,
  });

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
            seekToSeconds: widget.seekToSeconds,
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
  final int? seekToSeconds;

  const _LessonView({
    required this.state,
    required this.lessonId,
    required this.bookId,
    this.seekToSeconds,
  });

  @override
  State<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<_LessonView>
    with TickerProviderStateMixin {
  bool _quizAnswering = false;

  // Stable keys so the media coordinator can reach the (kept-alive) media tab
  // states across rebuilds and pause the outgoing player on a video↔audio switch.
  final GlobalKey _videoTabKey = GlobalKey();
  final GlobalKey _audioTabKey = GlobalKey();

  // Owned tab controller so tab changes can be rejected while a quiz is in
  // progress. The TabBar wraps each tab in its own InkWell (an ancestor we
  // can't remove), so the gesture block is backed by this hard controller-level
  // guard as the reliable stop.
  TabController? _tabController;
  int _quizTabIndex = 0;
  bool _enforcingLock = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _lockSnack;

  void _onAnsweringChanged(bool answering) {
    if (_quizAnswering != answering) {
      setState(() => _quizAnswering = answering);
    }
  }

  // While the quiz is active, any move off the quiz tab (a tap leaking through
  // the TabBar's InkWell) is reverted on the indexIsChanging notification,
  // before the target tab renders.
  void _enforceQuizLock() {
    final c = _tabController;
    if (c == null || !_quizAnswering || _enforcingLock) return;
    if (_quizTabIndex >= 0 && c.index != _quizTabIndex) {
      _enforcingLock = true;
      c.index = _quizTabIndex; // jump back, cancels the in-flight animateTo
      _enforcingLock = false;
    }
  }

  void _showQuizLockedSnackBar() {
    // Don't stack on rapid taps: ignore while one is already showing.
    if (_lockSnack != null) return;
    _lockSnack = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لازم تخلّص الاختبار الأول'),
        duration: Duration(seconds: 2),
      ),
    );
    _lockSnack!.closed.then((_) => _lockSnack = null);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_enforceQuizLock);
    _tabController?.dispose();
    super.dispose();
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
    // be re-watched from where the student left off. Each medium resumes from its
    // own saved position. Tabs only seek when > 0.
    final videoResumeSeconds = widget.state.videoPositionSeconds;
    final audioResumeSeconds = widget.state.audioPositionSeconds;

    final tabs = <_TabDef>[
      if (lesson.hasVideo)
        _TabDef(
          label: 'فيديو',
          icon: Icons.play_circle_outline,
          completionLabel: 'أكملت الفيديو',
          isVideoTab: true,
          content: VideoTab(
            key: _videoTabKey,
            videoUrl: lesson.videoUrl!,
            initialPositionSeconds: widget.seekToSeconds ?? videoResumeSeconds,
            lessonId: widget.lessonId,
            bookId: widget.bookId,
          ),
        ),
      if (lesson.hasAudio)
        _TabDef(
          label: 'صوت',
          icon: Icons.headphones_outlined,
          completionLabel: 'أكملت الصوت',
          isAudioTab: true,
          content: AudioTab(
            key: _audioTabKey,
            audioUrl: lesson.audioUrl!,
            lessonTitle: lesson.title,
            initialPositionSeconds: lesson.hasVideo
                ? audioResumeSeconds
                : (widget.seekToSeconds ?? audioResumeSeconds),
            lessonId: widget.lessonId,
            bookId: widget.bookId,
          ),
        ),
      if (lesson.hasPdf)
        _TabDef(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          completionLabel: 'أكملت القراءة',
          // Multiple PDFs (migration 0012) → a titled list; tapping opens the
          // full-screen viewer. The ONLY legacy branch: no usable rows but a
          // mirrored pdfUrl still present (pre-migration / never-re-saved) →
          // inline. The empty state is defensive — unreachable while the DB
          // mirror trigger holds, but avoids a null-check crash if it doesn't.
          content: lesson.orderedPdfs.isNotEmpty
              ? PdfListTab(pdfs: lesson.orderedPdfs)
              : (lesson.pdfUrl != null
                    ? PdfTab(pdfUrl: lesson.pdfUrl!)
                    : const SheikhyEmptyState(
                        icon: Icons.picture_as_pdf_outlined,
                        heading: 'لا توجد ملفات',
                        subtitle: 'لم تُضَف ملفات PDF لهذا الدرس بعد',
                      )),
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
              : AccountGate(
                  reason: GateReason.enrollment,
                  bookId: widget.bookId,
                  returnTo:
                      '/lessons/${widget.lessonId}?bookId=${widget.bookId}',
                  title: 'الاختبار غير متاح الآن',
                  guestMessage: 'سجّل حساباً أولاً عشان تقدر تحل الاختبار',
                  enrolledMessage:
                      'سجّل في الكتاب أولاً عشان تقدر تحل الاختبار',
                ),
        ),
    ];

    final quizTabIndex = tabs.indexWhere((t) => t.label == 'اختبار');
    _quizTabIndex = quizTabIndex;

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

    // Own the tab controller (recreate only if the tab set size changes) so the
    // quiz lock can hard-reject index changes. Replaces DefaultTabController.
    if (_tabController == null || _tabController!.length != tabs.length) {
      final previousIndex = _tabController?.index ?? 0;
      _tabController?.removeListener(_enforceQuizLock);
      _tabController?.dispose();
      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: previousIndex.clamp(0, tabs.length - 1),
      );
      _tabController!.addListener(_enforceQuizLock);
    }

    return BlocProvider<NotesCubit>(
      create: (ctx) => NotesCubit(
        LessonNotesSource(
          ctx.read<NotesRepository>(),
          lessonId: widget.lessonId,
          bookId: widget.bookId,
        ),
      )..load(),
      child: PopScope(
        canPop: !_quizAnswering,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await showLeaveQuizDialog(context);
          if (leave && context.mounted) context.pop();
        },
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: Column(
            children: [
              _MediaTabCoordinator(
                controller: _tabController!,
                tabs: tabs,
                videoTabKey: _videoTabKey,
                audioTabKey: _audioTabKey,
              ),
              _LessonHeader(
                state: widget.state,
                onAskTap: () => _openAskSheet(context),
                onBack: _handleBack,
              ),
              _LessonTabBar(
                controller: _tabController!,
                tabs: tabs,
                quizLocked: _quizAnswering,
                quizTabIndex: quizTabIndex,
                onLockedTap: _showQuizLockedSnackBar,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: _quizAnswering
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  children: tabs.map((t) => t.content).toList(),
                ),
              ),
              _LessonActionBar(
                controller: _tabController!,
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
  final TabController controller;
  final List<_TabDef> tabs;
  final bool quizLocked;
  final int quizTabIndex;
  final VoidCallback onLockedTap;

  const _LessonTabBar({
    required this.controller,
    required this.tabs,
    required this.quizLocked,
    required this.quizTabIndex,
    required this.onLockedTap,
  });

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
        controller: controller,
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
        tabs: tabs.asMap().entries.map((e) {
          final tab = Tab(
            icon: Icon(e.value.icon, size: 20),
            text: e.value.label,
          );
          if (quizLocked && e.key != quizTabIndex) {
            // The TabBar wraps every tab in its own (Expanded) InkWell that
            // fills the whole cell — wider than the Tab's intrinsic content, so
            // taps in the surrounding margin would otherwise reach the InkWell.
            // Force our opaque catcher to fill the cell width (width: infinity),
            // keeping the label visually centered, so it wins the arena across
            // the entire cell and the InkWell's onTap never fires.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLockedTap,
              child: SizedBox(
                width: double.infinity,
                child: IgnorePointer(
                  child: Opacity(opacity: 0.38, child: Center(child: tab)),
                ),
              ),
            );
          }
          return tab;
        }).toList(),
      ),
    );
  }
}

// ── Tab-aware action bar ──────────────────────────────────────────────────────

class _LessonActionBar extends StatefulWidget {
  final TabController controller;
  final List<_TabDef> tabs;
  final LessonLoaded state;
  final String bookId;

  const _LessonActionBar({
    required this.controller,
    required this.tabs,
    required this.state,
    required this.bookId,
  });

  @override
  State<_LessonActionBar> createState() => _LessonActionBarState();
}

class _LessonActionBarState extends State<_LessonActionBar> {
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.controller.index;
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(_LessonActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
      _activeIndex = widget.controller.index;
    }
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() => _activeIndex = widget.controller.index);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
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
          if (quizIndex >= 0) widget.controller.animateTo(quizIndex);
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

// ── Media tab coordinator ─────────────────────────────────────────────────────
//
// Renders nothing. Listens to the owned tab controller (passed in). Media tabs
// are kept alive, so playback continues in the background across non-media tabs
// (quiz/PDF). To avoid two players sounding at once, entering a media tab pauses
// the OTHER media tab (covers video↔audio directly and the transitive
// video→PDF→audio case). Position saving is handled by the tabs themselves
// (15s timer while playing + dispose() on back).
class _MediaTabCoordinator extends StatefulWidget {
  final TabController controller;
  final List<_TabDef> tabs;
  final GlobalKey videoTabKey;
  final GlobalKey audioTabKey;

  const _MediaTabCoordinator({
    required this.controller,
    required this.tabs,
    required this.videoTabKey,
    required this.audioTabKey,
  });

  @override
  State<_MediaTabCoordinator> createState() => _MediaTabCoordinatorState();
}

class _MediaTabCoordinatorState extends State<_MediaTabCoordinator> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(_MediaTabCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    final controller = widget.controller;
    if (!controller.indexIsChanging) return;
    final entering = controller.index;
    if (entering < 0 || entering >= widget.tabs.length) return;
    final tab = widget.tabs[entering];
    // Entering a media tab pauses the other media player; entering a non-media
    // tab (quiz/PDF) pauses nothing, so the current media keeps playing.
    if (tab.isVideoTab) {
      _pause(widget.audioTabKey);
    } else if (tab.isAudioTab) {
      _pause(widget.videoTabKey);
    }
  }

  void _pause(GlobalKey key) {
    if (key.currentState case final MediaTabController tab) {
      tab.pausePlayback();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Tab definition ────────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final IconData icon;
  final String? completionLabel;
  final Widget content;
  final bool isVideoTab;
  final bool isAudioTab;

  const _TabDef({
    required this.label,
    required this.icon,
    required this.completionLabel,
    required this.content,
    this.isVideoTab = false,
    this.isAudioTab = false,
  });
}
