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
import '../../lesson/data/lesson_repository.dart';
import '../../qa/cubit/qa_cubit.dart';
import '../../qa/data/qa_repository.dart';
import '../../qa/widgets/ask_question_sheet.dart';
import '../cubit/lesson_cubit.dart';
import '../cubit/lesson_state.dart';
import '../widgets/audio_tab.dart';
import '../widgets/pdf_tab.dart';
import '../widgets/quiz_tab.dart';
import '../widgets/video_tab.dart';

class LessonPage extends StatefulWidget {
  final String lessonId;
  final String bookId;

  const LessonPage({
    super.key,
    required this.lessonId,
    required this.bookId,
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
    return BlocBuilder<LessonCubit, LessonState>(
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
              onRetry: () => context
                  .read<LessonCubit>()
                  .loadLesson(lessonId, bookId),
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
          bottom: BorderSide(color: AppColors.border, width: AppBorders.hairline),
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

class _LessonView extends StatelessWidget {
  final LessonLoaded state;
  final String lessonId;
  final String bookId;

  const _LessonView({
    required this.state,
    required this.lessonId,
    required this.bookId,
  });

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
          bookId: bookId,
          lessonId: lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = state.lesson;
    final lessonRepo = context.read<LessonRepository>();

    final tabs = <_TabDef>[
      if (lesson.hasVideo)
        _TabDef(
          label: 'فيديو',
          icon: Icons.play_circle_outline,
          completionLabel: 'أكملت الفيديو',
          content: VideoTab(
            videoUrl: lesson.videoUrl!,
            initialPositionSeconds: state.lastPositionSeconds,
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
          ),
        ),
      if (lesson.hasPdf)
        _TabDef(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          completionLabel: 'أكملت القراءة',
          content: PdfTab(pdfUrl: lesson.pdfUrl!),
        ),
      if (state.hasQuizQuestions)
        _TabDef(
          label: 'اختبار',
          icon: Icons.quiz_outlined,
          completionLabel: null,
          content: RepositoryProvider.value(
            value: lessonRepo,
            child: QuizTab(lessonId: lessonId),
          ),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _LessonHeader(
              state: state,
              onAskTap: () => _openAskSheet(context),
              onBack: () => context.pop(),
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

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _LessonHeader(
              state: state,
              onAskTap: () => _openAskSheet(context),
              onBack: () => context.pop(),
            ),
            _LessonTabBar(tabs: tabs),
            Expanded(
              child: TabBarView(
                children: tabs.map((t) => t.content).toList(),
              ),
            ),
            _LessonActionBar(
              tabs: tabs,
              state: state,
              bookId: bookId,
            ),
          ],
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
          bottom: BorderSide(color: AppColors.border, width: AppBorders.hairline),
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
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.inkFaint),
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
          bottom: BorderSide(color: AppColors.border, width: AppBorders.hairline),
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
            .map(
              (t) => Tab(
                icon: Icon(t.icon, size: 20),
                text: t.label,
              ),
            )
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

  String get _activeCompletionLabel {
    final tab = _activeIndex < widget.tabs.length
        ? widget.tabs[_activeIndex]
        : null;
    return tab?.completionLabel ?? 'حفظ الدرس';
  }

  bool get _isQuizTab {
    final tab = _activeIndex < widget.tabs.length
        ? widget.tabs[_activeIndex]
        : null;
    return tab?.completionLabel == null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isQuizTab) return const SizedBox.shrink();

    final state = widget.state;

    final String label;
    final VoidCallback? onPressed;

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
      label = _activeCompletionLabel;
      onPressed = () => context.read<LessonCubit>().markVideoWatched();
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
            icon: state.isCompleted && state.nextLessonId == null
                ? const Icon(Icons.check)
                : null,
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

  const _TabDef({
    required this.label,
    required this.icon,
    required this.completionLabel,
    required this.content,
  });
}
