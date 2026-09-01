// lib/features/books/view/book_details_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/progress_bar.dart';
import '../cubit/book_details_cubit.dart';
import '../cubit/book_details_state.dart';
import '../widgets/final_exam_card.dart';
import '../widgets/lesson_list_item.dart';

class BookDetailsPage extends StatefulWidget {
  final String bookId;
  const BookDetailsPage({super.key, required this.bookId});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BookDetailsCubit>().loadBook(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        body: BlocConsumer<BookDetailsCubit, BookDetailsState>(
          listener: (context, state) {
            if (state is BookDetailsLoaded) {
              // Return from lesson page → refresh progress
            }
          },
          builder: (context, state) {
            return switch (state) {
              BookDetailsInitial() || BookDetailsLoading() =>
                CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      leading: const BackButton(),
                      title: const Text('تفاصيل الكتاب'),
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              BookDetailsError(:final message) => CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      leading: const BackButton(),
                      title: const Text('تفاصيل الكتاب'),
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    SliverFillRemaining(
                      child: ErrorState(
                        message: message,
                        onRetry: () => context
                            .read<BookDetailsCubit>()
                            .loadBook(widget.bookId),
                      ),
                    ),
                  ],
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

class _BookDetailsView extends StatelessWidget {
  final BookDetailsLoaded state;
  final String bookId;

  const _BookDetailsView({required this.state, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          leading: const BackButton(),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              state.book.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                shadows: [
                  const Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
            background: state.book.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: state.book.coverImageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black38,
                    colorBlendMode: BlendMode.darken,
                    placeholder: (ctx, url) => Container(
                        color: colorScheme.surfaceContainerHighest),
                    errorWidget: (ctx, url, err) =>
                        _DefaultCover(colorScheme: colorScheme),
                  )
                : _DefaultCover(colorScheme: colorScheme),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.question_answer_outlined,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              tooltip: 'الأسئلة والأجوبة',
              onPressed: () {
                if (!state.isEnrolled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سجّل في الكتاب أولاً للوصول إلى الأسئلة'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                context.push('/books/$bookId/qa');
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress section (only when enrolled)
                if (state.isEnrolled) ...[
                  Row(
                    children: [
                      Text(
                        'التقدم في الكتاب',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(state.completionPercentage * 100).toInt()}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: state.completionPercentage >= 1.0
                              ? const Color(0xFFD4A017)
                              : colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ProgressBar(
                    value: state.completionPercentage,
                    height: 6,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Description
                if (state.book.description != null) ...[
                  Text(
                    state.book.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Divider(
                    color: colorScheme.outlineVariant
                        .withValues(alpha: 0.5)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'الدروس',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lessons list
        state.lessons.isEmpty
            ? const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'لا توجد دروس منشورة بعد',
                ),
              )
            : SliverList.separated(
                itemCount: state.lessons.length,
                separatorBuilder: (ctx, i) => Divider(
                  height: 1,
                  indent: AppSpacing.md + 38,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final item = state.lessons[index];
                  return LessonListItem(
                    item: item,
                    isEnrolled: state.isEnrolled,
                    onTap: () {
                      if (!state.isEnrolled) {
                        _showEnrollDialog(context);
                        return;
                      }
                      context
                          .push('/lessons/${item.lesson.id}?bookId=$bookId')
                          .then((_) {
                        if (context.mounted) {
                          context
                              .read<BookDetailsCubit>()
                              .refreshProgress(bookId);
                        }
                      });
                    },
                  );
                },
              ),

        // Final exam card
        if (state.hasFinalExam)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.md, bottom: AppSpacing.sm),
              child: FinalExamCard(
                isEnrolled: state.isEnrolled,
                isExamPublished: state.hasFinalExam,
                completionPercentage: state.completionPercentage,
                onTap: () => context.push(
                  '/books/$bookId/exam',
                  extra: state.book.title,
                ),
              ),
            ),
          ),

        // Bottom enroll / continue button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
            child: _EnrollButton(state: state, bookId: bookId),
          ),
        ),
      ],
    );
  }

  void _showEnrollDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('التسجيل في الكتاب'),
        content: Text(
          'هل تريد التسجيل في كتاب "${state.book.title}"؟ سيتمكّن من الوصول إلى جميع دروسه.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogCtx.pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              dialogCtx.pop();
              context.read<BookDetailsCubit>().enroll(bookId);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }
}

class _EnrollButton extends StatelessWidget {
  final BookDetailsLoaded state;
  final String bookId;

  const _EnrollButton({required this.state, required this.bookId});

  @override
  Widget build(BuildContext context) {
    if (state.isEnrolled) {
      // Find first incomplete lesson
      final nextLesson = state.lessons
          .where((l) => !l.isCompleted)
          .firstOrNull;

      return FilledButton.icon(
        onPressed: nextLesson == null
            ? null
            : () => context.push(
                '/lessons/${nextLesson.lesson.id}?bookId=$bookId'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('استمرار المذاكرة'),
      );
    }

    return BlocBuilder<BookDetailsCubit, BookDetailsState>(
      buildWhen: (p, c) => c is BookDetailsLoaded,
      builder: (context, state) {
        final loaded = state is BookDetailsLoaded ? state : null;
        return FilledButton.icon(
          onPressed: loaded?.isEnrolling ?? false
              ? null
              : () => _showEnrollDialog(context, bookId),
          icon: loaded?.isEnrolling ?? false
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.how_to_reg),
          label: const Text('تسجيل في الكتاب'),
        );
      },
    );
  }

  void _showEnrollDialog(BuildContext context, String bookId) {
    final cubit = context.read<BookDetailsCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('التسجيل في الكتاب'),
        content: const Text(
            'هل تريد التسجيل؟ سيتمكّن من الوصول إلى جميع دروسه.'),
        actions: [
          TextButton(
            onPressed: () => dialogCtx.pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              dialogCtx.pop();
              cubit.enroll(bookId);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }
}

class _DefaultCover extends StatelessWidget {
  final ColorScheme colorScheme;
  const _DefaultCover({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.menu_book,
          size: 72,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
