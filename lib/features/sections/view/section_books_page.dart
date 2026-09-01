// lib/features/sections/view/section_books_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../models/book_with_progress_entity.dart';
import '../cubit/section_books_cubit.dart';
import '../cubit/section_books_state.dart';

class SectionBooksPage extends StatefulWidget {
  final String sectionId;
  final String? sectionName;

  const SectionBooksPage({
    super.key,
    required this.sectionId,
    this.sectionName,
  });

  @override
  State<SectionBooksPage> createState() => _SectionBooksPageState();
}

class _SectionBooksPageState extends State<SectionBooksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookWithProgressEntity> _filterBooks(
    List<BookWithProgressEntity> books,
  ) {
    if (_query.isEmpty) return books;
    return books
        .where((b) => b.book.title.contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sectionName?.isNotEmpty == true
              ? widget.sectionName!
              : 'كتب القسم',
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<SectionBooksCubit, SectionBooksState>(
        builder: (context, state) {
          if (state is SectionBooksLoading || state is SectionBooksInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SectionBooksError) {
            return ErrorState(
              message: state.message,
              onRetry: () => context
                  .read<SectionBooksCubit>()
                  .loadBooks(widget.sectionId),
            );
          }

          if (state is SectionBooksEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'لا توجد كتب في هذا القسم بعد',
            );
          }

          if (state is SectionBooksLoaded) {
            final filtered = _filterBooks(state.books);

            return RefreshIndicator(
              onRefresh: () => context
                  .read<SectionBooksCubit>()
                  .loadBooks(widget.sectionId),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'بحث في الكتب...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() => _query = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            message: 'لا توجد نتائج لـ "$_query"',
                          )
                        : ListView.separated(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.lg,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) =>
                                _BookListItem(item: filtered[index]),
                          ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final BookWithProgressEntity item;

  const _BookListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = item.book;
    final hasProgress = item.isEnrolled && item.totalLessons > 0;
    final percent = (item.progress * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/books/${book.id}'),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 76,
                  child: book.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: book.coverImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              _Thumb(title: book.title, theme: theme),
                          errorWidget: (_, _, _) =>
                              _Thumb(title: book.title, theme: theme),
                        )
                      : _Thumb(title: book.title, theme: theme),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.description != null &&
                        book.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        book.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (hasProgress) ...[
                      ProgressBar(value: item.progress),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$percent% • ${item.completedLessons}/${item.totalLessons} درس',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            item.totalLessons > 0
                                ? '${item.totalLessons} درس'
                                : 'ابدأ التعلّم',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
                child: Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _Thumb({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0] : '؟',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
