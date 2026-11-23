// lib/features/admin/levels/view/admin_level_book_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/assignable_book_entity.dart';
import '../cubit/admin_level_book_picker_cubit.dart';
import '../cubit/admin_level_book_picker_state.dart';

/// Picks a book to add to the current level. A free book is added on tap; a book
/// already in another level shows "في المستوى: X" and tapping asks to confirm a
/// MOVE. The chosen book id is returned via `context.pop` to the caller, which
/// performs the assign/move.
class AdminLevelBookPickerPage extends StatelessWidget {
  const AdminLevelBookPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة كتاب للمستوى')),
      body: BlocBuilder<AdminLevelBookPickerCubit, AdminLevelBookPickerState>(
        builder: (context, state) {
          return switch (state) {
            AdminLevelBookPickerLoading() || AdminLevelBookPickerInitial() =>
              const Center(child: CircularProgressIndicator()),
            AdminLevelBookPickerError(:final message) => ErrorState(
              message: message,
              onRetry: () => context.read<AdminLevelBookPickerCubit>().load(),
            ),
            AdminLevelBookPickerLoaded(:final books) when books.isEmpty =>
              const EmptyState(
                icon: Icons.menu_book_outlined,
                message: 'لا توجد كتب متاحة للإضافة',
              ),
            AdminLevelBookPickerLoaded(:final books) => ListView.builder(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              itemCount: books.length,
              itemBuilder: (context, i) => _PickBookItem(book: books[i]),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _PickBookItem extends StatelessWidget {
  final AssignableBookEntity book;
  const _PickBookItem({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(book.title),
        subtitle: book.hasLevel
            ? Text(
                'في المستوى: ${book.currentLevelName ?? ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(
          book.hasLevel ? Icons.swap_horiz : Icons.add,
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: () => _onTap(context),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    if (!book.hasLevel) {
      context.pop(book.id);
      return;
    }
    // Already in another level — confirm the move.
    final move = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('نقل الكتاب'),
        content: Text(
          'الكتاب "${book.title}" موجود حالياً في المستوى '
          '"${book.currentLevelName ?? ''}". هل تريد نقله إلى هذا المستوى؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('نقل'),
          ),
        ],
      ),
    );
    if (move == true && context.mounted) context.pop(book.id);
  }
}
