// lib/features/admin/levels/view/admin_levels_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/level_entity.dart';
import '../cubit/admin_levels_cubit.dart';
import '../cubit/admin_levels_state.dart';

class AdminLevelsPage extends StatelessWidget {
  const AdminLevelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستويات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminLevelsCubit>().load(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLevel(context),
        icon: const Icon(Icons.add),
        label: const Text('مستوى جديد'),
      ),
      body: BlocConsumer<AdminLevelsCubit, AdminLevelsState>(
        listenWhen: (prev, curr) =>
            curr is AdminLevelsLoaded &&
            (curr.transientSuccess != null || curr.transientError != null),
        listener: (context, state) {
          if (state is! AdminLevelsLoaded) return;
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
            AdminLevelsLoading() || AdminLevelsInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            AdminLevelsError(:final message) => ErrorState(
              message: message,
              onRetry: () => context.read<AdminLevelsCubit>().load(),
            ),
            AdminLevelsLoaded(:final levels) when levels.isEmpty => EmptyState(
              icon: Icons.school_outlined,
              message: 'لا توجد مستويات بعد',
              actionLabel: 'إضافة مستوى',
              onAction: () => _addLevel(context),
            ),
            AdminLevelsLoaded(:final levels) => ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: levels.length,
              onReorder: context.read<AdminLevelsCubit>().reorder,
              itemBuilder: (context, i) => _LevelListItem(
                key: ValueKey(levels[i].id),
                level: levels[i],
                index: i,
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Future<void> _addLevel(BuildContext context) async {
    final cubit = context.read<AdminLevelsCubit>();
    await context.push('/admin/levels/new');
    if (context.mounted) cubit.load();
  }
}

class _LevelListItem extends StatelessWidget {
  final LevelEntity level;
  final int index;

  const _LevelListItem({
    required super.key,
    required this.level,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: do NOT read the cubit in build(). During a drag, ReorderableListView
    // rebuilds this item inside an Overlay outside the BlocProvider, so a
    // build-time context.read throws. Read it only inside callbacks.
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
        title: Text(level.name),
        subtitle: Text(
          '${level.bookCount} ${level.bookCount == 1 ? 'كتاب' : 'كتب'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () => _edit(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<AdminLevelsCubit>();
    await context.push('/admin/levels/${level.id}/edit', extra: level);
    if (context.mounted) cubit.load();
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<AdminLevelsCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف المستوى'),
        content: Text(
          'هل تريد حذف مستوى "${level.name}"؟\n\n'
          'سيتم إلغاء ربط الكتب بهذا المستوى فقط، ولن يتم حذف الكتب نفسها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.deleteLevel(level.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
