// lib/features/admin/levels/view/admin_level_books_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/book_entity.dart';
import '../cubit/admin_level_books_cubit.dart';
import '../cubit/admin_level_books_state.dart';

/// The ordered books of one level. Drag to reorder, remove to unlink (the book
/// is never deleted), or add a book via the picker.
class AdminLevelBooksPage extends StatelessWidget {
  final String levelId;
  final String levelName;

  const AdminLevelBooksPage({
    super.key,
    required this.levelId,
    required this.levelName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كتب: $levelName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminLevelBooksCubit>().load(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBook(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة كتاب'),
      ),
      body: BlocConsumer<AdminLevelBooksCubit, AdminLevelBooksState>(
        listenWhen: (prev, curr) =>
            curr is AdminLevelBooksLoaded &&
            (curr.transientSuccess != null || curr.transientError != null),
        listener: (context, state) {
          if (state is! AdminLevelBooksLoaded) return;
          final messenger = ScaffoldMessenger.of(context);
          if (state.transientSuccess != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientSuccess!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state.transientError != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientError!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            AdminLevelBooksLoading() || AdminLevelBooksInitial() =>
              const Center(child: CircularProgressIndicator()),
            AdminLevelBooksError(:final message) => ErrorState(
              message: message,
              onRetry: () => context.read<AdminLevelBooksCubit>().load(),
            ),
            AdminLevelBooksLoaded(:final books) when books.isEmpty =>
              EmptyState(
                icon: Icons.menu_book_outlined,
                message: 'لا توجد كتب في هذا المستوى',
                actionLabel: 'إضافة كتاب',
                onAction: () => _addBook(context),
              ),
            AdminLevelBooksLoaded(:final books) => ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: books.length,
              onReorder: context.read<AdminLevelBooksCubit>().reorder,
              itemBuilder: (context, i) => _LevelBookItem(
                key: ValueKey(books[i].id),
                book: books[i],
                index: i,
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Future<void> _addBook(BuildContext context) async {
    final cubit = context.read<AdminLevelBooksCubit>();
    final bookId = await context.push<String>(
      '/admin/levels/$levelId/books/add',
    );
    if (bookId != null) cubit.addBook(bookId);
  }
}

class _LevelBookItem extends StatelessWidget {
  final BookEntity book;
  final int index;

  const _LevelBookItem({
    required super.key,
    required this.book,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Do NOT read the cubit in build() — the drag Overlay sits outside the
    // BlocProvider. Read it only in callbacks.
    final isDraft = book.status != 'published';
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.xs),
            child: Icon(Icons.drag_handle, color: Colors.grey),
          ),
        ),
        title: Text(book.title),
        subtitle: isDraft
            ? Text(
                'مسودة',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.link_off, color: Colors.red),
          tooltip: 'إزالة من المستوى',
          onPressed: () => _confirmRemove(context),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final cubit = context.read<AdminLevelBooksCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('إزالة الكتاب'),
        content: Text(
          'هل تريد إزالة كتاب "${book.title}" من هذا المستوى؟\n\n'
          'سيُلغى ربط الكتاب بالمستوى فقط، ولن يتم حذف الكتاب نفسه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.removeBook(book.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }
}
