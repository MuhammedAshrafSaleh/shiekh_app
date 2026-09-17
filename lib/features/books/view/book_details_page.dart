// lib/features/books/view/book_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/girih_background.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/ornament_divider.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_progress_bar.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../notes/cubit/notes_cubit.dart';
import '../../notes/view/notes_tab.dart';
import '../cubit/book_details_cubit.dart';
import '../cubit/book_details_state.dart';
import '../widgets/final_exam_card.dart';
import '../widgets/lesson_list_item.dart';

/// True when the current session is an anonymous guest.
bool _isGuest(BuildContext context) {
  final s = context.read<AuthCubit>().state;
  return s is AuthAuthenticated && s.isGuest;
}

/// Basic (Stage 2) guest gate: prompt to create an account, carrying the
/// destination so conversion returns here and auto-enrolls. Replaced by the
/// shared AccountGate in Stage 3.
void _showGuestSignupGate(
  BuildContext context, {
  required String returnTo,
  required String bookId,
}) {
  final signupLoc = Uri(
    path: '/signup',
    queryParameters: {'returnTo': returnTo, 'autoEnrollBookId': bookId},
  ).toString();

  showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
    builder: (dialogCtx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.s8,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_add_alt_1_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'أنشئ حساباً لمتابعة التعلّم',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'الدرس الأول متاح للجميع. لمتابعة بقية الدروس أنشئ حساباً مجانياً وسنعيدك إلى حيث توقفت.',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s5),
            SheikhyButton.primary(
              fullWidth: true,
              label: 'أنشئ حساباً',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () {
                dialogCtx.pop();
                context.push(signupLoc);
              },
            ),
            const SizedBox(height: AppSpacing.s2),
            SheikhyButton.secondary(
              fullWidth: true,
              label: 'لاحقاً',
              onPressed: () => dialogCtx.pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class BookDetailsPage extends StatefulWidget {
  final String bookId;
  const BookDetailsPage({super.key, required this.bookId});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  GoRouter? _router;
  late final VoidCallback _routeListener;
  String _lastKnownRoute = '';

  @override
  void initState() {
    super.initState();
    context.read<BookDetailsCubit>().loadBook(widget.bookId);
    _routeListener = _handleRouteChange;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_routeListener);
      _router = router;
      router.routerDelegate.addListener(_routeListener);
    }
  }

  void _handleRouteChange() {
    if (!mounted) return;
    final currentPath =
        _router?.routerDelegate.currentConfiguration.uri.path ?? '';
    final bookPath = '/books/${widget.bookId}';
    final returningFromLesson =
        _lastKnownRoute.startsWith('/lessons/') &&
        currentPath == bookPath;
    final returningFromNotes =
        _lastKnownRoute.startsWith('$bookPath/notes/') &&
        currentPath == bookPath;
    _lastKnownRoute = currentPath;
    if (returningFromLesson) {
      final cubit = context.read<BookDetailsCubit>();
      if (cubit.state is BookDetailsLoaded) {
        cubit.refreshProgress(widget.bookId);
      }
    }
    if (returningFromLesson || returningFromNotes) {
      context.read<NotesCubit>().loadBookNotes(widget.bookId);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: BlocBuilder<BookDetailsCubit, BookDetailsState>(
          builder: (context, state) {
            return switch (state) {
              BookDetailsInitial() || BookDetailsLoading() =>
                _BookDetailsSkeleton(bookId: widget.bookId),
              BookDetailsError(:final message) => _BookDetailsErrorView(
                message: message,
                bookId: widget.bookId,
              ),
              BookDetailsLoaded() => _BookDetailsView(
                state: state,
                bookId: widget.bookId,
              ),
              _ => const SizedBox.shrink(),
            };
          },
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _BookDetailsSkeleton extends StatelessWidget {
  final String bookId;
  const _BookDetailsSkeleton({required this.bookId});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const _MinimalHeader(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: double.infinity, height: 10),
                const SizedBox(height: AppSpacing.s5),
                const _SkeletonBox(width: double.infinity, height: 16),
                const SizedBox(height: AppSpacing.s2),
                const _SkeletonBox(width: 200, height: 16),
                const SizedBox(height: AppSpacing.s2),
                const _SkeletonBox(width: 160, height: 16),
                const SizedBox(height: AppSpacing.s6),
                ...List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: const Row(
                      children: [
                        _SkeletonBox(width: 32, height: 32, radius: 16),
                        SizedBox(width: AppSpacing.s4),
                        Expanded(
                          child: _SkeletonBox(
                            width: double.infinity,
                            height: 14,
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
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = AppSpacing.s2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Compact pinned header (skeleton + error states) ───────────────────────────

class _MinimalHeader extends StatelessWidget {
  const _MinimalHeader();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_forward_ios,
          size: 20,
          color: AppColors.inkInvert,
        ),
        tooltip: 'رجوع',
        onPressed: () => context.pop(),
      ),
      title: Text(
        'تفاصيل الكتاب',
        style: GoogleFonts.reemKufi(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.inkInvert,
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _BookDetailsErrorView extends StatelessWidget {
  final String message;
  final String bookId;

  const _BookDetailsErrorView({required this.message, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _MinimalHeader(),
        SliverFillRemaining(
          child: SheikhyErrorState(
            heading: 'تعذّر تحميل الكتاب',
            message: message,
            onRetry: () => context.read<BookDetailsCubit>().loadBook(bookId),
          ),
        ),
      ],
    );
  }
}

// ── Full loaded view ──────────────────────────────────────────────────────────

class _BookDetailsView extends StatefulWidget {
  final BookDetailsLoaded state;
  final String bookId;

  const _BookDetailsView({required this.state, required this.bookId});

  @override
  State<_BookDetailsView> createState() => _BookDetailsViewState();
}

class _BookDetailsViewState extends State<_BookDetailsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      context.read<NotesCubit>().loadBookNotes(widget.bookId);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bookId = widget.bookId;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _HeritageSliverHeader(state: state, bookId: bookId),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s5,
              AppSpacing.pageGutter,
              AppSpacing.s2,
            ),
            child: _BookMeta(state: state),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: OrnamentDivider(),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _BookTabBarDelegate(_tabController),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDurusTab(state, bookId),
          NotesTab(bookId: bookId, lessons: state.lessons),
        ],
      ),
    );
  }

  Widget _buildDurusTab(BookDetailsLoaded state, String bookId) {
    return CustomScrollView(
      slivers: [
        if (state.lessons.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s7),
              child: SheikhyEmptyState(
                icon: Icons.menu_book_outlined,
                heading: 'لا توجد دروس',
                subtitle: 'لم يُنشر أي درس في هذا الكتاب بعد',
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: state.lessons.length,
            separatorBuilder: (_, index) => Container(
              margin: const EdgeInsetsDirectional.only(
                start: AppSpacing.pageGutter + 32 + AppSpacing.s4,
              ),
              height: 1,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (_, index) {
              final item = state.lessons[index];
              final isFirstLesson = index == 0;
              final isSequentiallyLocked =
                  state.isEnrolled &&
                  index > 0 &&
                  !state.lessons[index - 1].isCompleted;
              return LessonListItem(
                item: item,
                isEnrolled: state.isEnrolled,
                isOpenToAll: isFirstLesson,
                isLocked: isSequentiallyLocked,
                onTap: () {
                  if (isFirstLesson) {
                    _openLesson(item.lesson.id);
                    return;
                  }
                  if (!state.isEnrolled) {
                    _gateUnenrolled(item.lesson.id);
                    return;
                  }
                  if (isSequentiallyLocked) {
                    _showLockedLessonDialog();
                    return;
                  }
                  _openLesson(item.lesson.id);
                },
              );
            },
          ),

        if (state.hasFinalExam)
          SliverToBoxAdapter(
            child: FinalExamCard(
              isEnrolled: state.isEnrolled,
              isExamPublished: state.hasFinalExam,
              completionPercentage: state.completionPercentage,
              bestAttempt: state.bestExamAttempt,
              onTap: () => context.push(
                '/books/$bookId/exam',
                extra: state.book.title,
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s4,
              AppSpacing.pageGutter,
              AppSpacing.s7,
            ),
            child: _ActionButton(state: state, bookId: bookId),
          ),
        ),
      ],
    );
  }

  void _openLesson(String lessonId) {
    context.push('/lessons/$lessonId?bookId=${widget.bookId}').then((_) {
      if (mounted) {
        context.read<BookDetailsCubit>().refreshProgress(widget.bookId);
      }
    });
  }

  // Lesson 2+ tapped without enrollment: a guest is prompted to create an
  // account (returning to this exact lesson); a registered user to enroll.
  void _gateUnenrolled(String lessonId) {
    if (_isGuest(context)) {
      _showGuestSignupGate(
        context,
        returnTo: '/lessons/$lessonId?bookId=${widget.bookId}',
        bookId: widget.bookId,
      );
    } else {
      _showEnrollConfirmDialog(
        context: context,
        bookTitle: widget.state.book.title,
        onConfirm: () =>
            context.read<BookDetailsCubit>().enroll(widget.bookId),
      );
    }
  }

  void _showLockedLessonDialog() {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageGutter,
          vertical: AppSpacing.s8,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.gold,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'محاضرة مقفلة',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'يجب إتمام المحاضرة السابقة وامتحاناتها أولاً قبل الانتقال إلى هذه المحاضرة',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s5),
              SheikhyButton.secondary(
                fullWidth: true,
                label: 'حسناً',
                onPressed: () => dialogCtx.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pinned tab bar for NestedScrollView ───────────────────────────────────────

class _BookTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;

  const _BookTabBarDelegate(this.controller);

  static const double _height = 48;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
        tabs: const [
          Tab(text: 'الدروس'),
          Tab(text: 'المحفوظات'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_BookTabBarDelegate oldDelegate) =>
      controller != oldDelegate.controller;
}

// ── Shared enrollment confirmation dialog ─────────────────────────────────────

void _showEnrollConfirmDialog({
  required BuildContext context,
  required String bookTitle,
  required VoidCallback onConfirm,
}) {
  showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
    builder: (dialogCtx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.s8,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.how_to_reg_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'التسجيل في الكتاب',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'هل تريد التسجيل في كتاب "$bookTitle"؟ ستتمكّن من الوصول إلى جميع دروسه.',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s5),
            SheikhyButton.primary(
              fullWidth: true,
              label: 'تسجيل',
              icon: const Icon(Icons.how_to_reg_outlined),
              onPressed: () {
                dialogCtx.pop();
                onConfirm();
              },
            ),
            const SizedBox(height: AppSpacing.s2),
            SheikhyButton.secondary(
              fullWidth: true,
              label: 'إلغاء',
              onPressed: () => dialogCtx.pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Heritage SliverAppBar header ──────────────────────────────────────────────

class _HeritageSliverHeader extends StatelessWidget {
  final BookDetailsLoaded state;
  final String bookId;

  const _HeritageSliverHeader({required this.state, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: AppColors.ink.withValues(alpha: 0.15),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_forward_ios,
          size: 20,
          color: AppColors.inkInvert,
        ),
        tooltip: 'رجوع',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: Text(
        state.book.title,
        style: GoogleFonts.reemKufi(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.inkInvert,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.question_answer_outlined,
            color: AppColors.inkInvert,
            size: 22,
          ),
          tooltip: 'الأسئلة والأجوبة',
          onPressed: () => _onQaTapped(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: EdgeInsets.zero,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Primary green fill
            DecoratedBox(decoration: BoxDecoration(color: AppColors.primary)),
            // Girih lattice
            GirihBackground(color: AppColors.goldLight, opacity: 0.14),
            // MihrabArch at bottom-end, bleeds off edge (mirrors course card pattern)
            const PositionedDirectional(
              bottom: -24,
              end: AppSpacing.s5,
              child: MihrabArch(width: 130, height: 160),
            ),
            // Book title at bottom-start in Aref Ruqaa (ceremonial display font)
            PositionedDirectional(
              bottom: AppSpacing.s5,
              start: AppSpacing.pageGutter,
              end: 150,
              child: Text(
                state.book.title,
                style: GoogleFonts.arefRuqaa(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkInvert,
                  height: 1.3,
                  shadows: const [
                    Shadow(color: Color(0x33000000), blurRadius: 8),
                  ],
                ),
                textAlign: TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onQaTapped(BuildContext context) {
    if (!state.isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'سجّل في الكتاب أولاً للوصول إلى الأسئلة',
            style: AppTextStyles.small.copyWith(color: AppColors.inkInvert),
          ),
          backgroundColor: AppColors.inkMuted,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    context.push('/books/$bookId/qa');
  }
}

// ── Progress + description ────────────────────────────────────────────────────

class _BookMeta extends StatelessWidget {
  final BookDetailsLoaded state;

  const _BookMeta({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isEnrolled) ...[
          Row(
            children: [
              Text(
                'التقدم في الكتاب',
                style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              Text(
                '${(state.completionPercentage * 100).toInt()}٪',
                style: AppTextStyles.small.copyWith(
                  color: state.completionPercentage >= 1.0
                      ? AppColors.gold
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          SheikhyProgressBar(
            value: state.completionPercentage,
            variant: state.completionPercentage >= 1.0
                ? SheikhyProgressVariant.gold
                : SheikhyProgressVariant.primary,
          ),
          const SizedBox(height: AppSpacing.s5),
        ],
        if (state.book.description != null)
          Text(
            state.book.description!,
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          ),
      ],
    );
  }
}

// ── Bottom action button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final BookDetailsLoaded state;
  final String bookId;

  const _ActionButton({required this.state, required this.bookId});

  @override
  Widget build(BuildContext context) {
    if (state.isEnrolled) {
      final nextLesson = state.lessons.where((l) => !l.isCompleted).firstOrNull;
      if (nextLesson == null) return const SizedBox.shrink();
      return SheikhyButton.primary(
        label: 'استمرار المذاكرة',
        icon: const Icon(Icons.play_arrow),
        fullWidth: true,
        onPressed: () =>
            context.push('/lessons/${nextLesson.lesson.id}?bookId=$bookId'),
      );
    }

    return BlocBuilder<BookDetailsCubit, BookDetailsState>(
      buildWhen: (p, c) => c is BookDetailsLoaded,
      builder: (context, s) {
        final loaded = s is BookDetailsLoaded ? s : state;
        final guest = _isGuest(context);
        return SheikhyButton.primary(
          label: guest ? 'أنشئ حساباً للتسجيل' : 'التسجيل في الكتاب',
          icon: Icon(
            guest ? Icons.person_add_alt_1_outlined : Icons.how_to_reg_outlined,
          ),
          fullWidth: true,
          isLoading: loaded.isEnrolling,
          onPressed: loaded.isEnrolling ? null : () => _onPressed(context),
        );
      },
    );
  }

  void _onPressed(BuildContext context) {
    if (_isGuest(context)) {
      // Guest can't enroll; convert first, then return here auto-enrolled.
      _showGuestSignupGate(context, returnTo: '/books/$bookId', bookId: bookId);
    } else {
      _showEnrollDialog(context);
    }
  }

  void _showEnrollDialog(BuildContext context) {
    _showEnrollConfirmDialog(
      context: context,
      bookTitle: state.book.title,
      onConfirm: () => context.read<BookDetailsCubit>().enroll(bookId),
    );
  }
}
