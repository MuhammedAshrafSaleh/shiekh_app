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

  const SectionBooksPage({super.key, required this.sectionId});

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
        title: const Text('كتب القسم'),
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
                        : ListView.builder(
                            itemCount: filtered.length,
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

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      onTap: () => context.go('/books/${item.book.id}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 64,
          child: item.book.coverImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: item.book.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      _Thumb(title: item.book.title, theme: theme),
                  errorWidget: (_, _, _) =>
                      _Thumb(title: item.book.title, theme: theme),
                )
              : _Thumb(title: item.book.title, theme: theme),
        ),
      ),
      title: Text(
        item.book.title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
        child: ProgressBar(value: item.progress),
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
