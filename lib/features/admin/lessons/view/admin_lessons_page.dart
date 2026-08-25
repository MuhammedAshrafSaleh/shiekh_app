// lib/features/admin/lessons/view/admin_lessons_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/lesson_entity.dart';
import '../cubit/admin_lesson_cubit.dart';
import '../cubit/admin_lesson_state.dart';

class AdminLessonsPage extends StatelessWidget {
  final String bookId;
  final String bookTitle;
  const AdminLessonsPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminLessonListCubit, AdminLessonListState>(
      listener: (context, state) {
        if (state is AdminLessonListError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('دروس: $bookTitle'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<AdminLessonListCubit>().load(bookId),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('درس جديد'),
            onPressed: () async {
              await context.push('/admin/books/$bookId/lessons/new');
              if (context.mounted) {
                context.read<AdminLessonListCubit>().refresh();
              }
            },
          ),
          body: switch (state) {
            AdminLessonListLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            AdminLessonListError() => ErrorState(
                message: state.message,
                onRetry: () =>
                    context.read<AdminLessonListCubit>().load(bookId),
              ),
            AdminLessonListEmpty() => EmptyState(
                icon: Icons.play_lesson_outlined,
                message: 'لا توجد دروس بعد',
                actionLabel: 'إضافة درس',
                onAction: () async {
                  await context.push('/admin/books/$bookId/lessons/new');
                  if (context.mounted) {
                    context.read<AdminLessonListCubit>().refresh();
                  }
                },
              ),
            AdminLessonListLoaded() => _ReorderableList(
                lessons: state.lessons,
                bookId: bookId,
              ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _ReorderableList extends StatefulWidget {
  final List<LessonEntity> lessons;
  final String bookId;
  const _ReorderableList({required this.lessons, required this.bookId});

  @override
  State<_ReorderableList> createState() => _ReorderableListState();
}

class _ReorderableListState extends State<_ReorderableList> {
  late List<LessonEntity> _lessons;

  @override
  void initState() {
    super.initState();
    _lessons = List.from(widget.lessons);
  }

  @override
  void didUpdateWidget(_ReorderableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessons != widget.lessons) {
      _lessons = List.from(widget.lessons);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final item = _lessons.removeAt(oldIndex);
    _lessons.insert(newIndex, item);
    setState(() {});

    final updates = _lessons.indexed
        .map((e) => (id: e.$2.id, orderIndex: e.$1 + 1))
        .toList();
    final ok = await context.read<AdminLessonListCubit>().reorder(updates);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فشل إعادة الترتيب'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<AdminLessonListCubit>().load(widget.bookId),
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        itemCount: _lessons.length,
        onReorderItem: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex),
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          return _LessonTile(
            key: ValueKey(lesson.id),
            lesson: lesson,
            bookId: widget.bookId,
            onRefresh: () =>
                context.read<AdminLessonListCubit>().load(widget.bookId),
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final LessonEntity lesson;
  final String bookId;
  final VoidCallback onRefresh;

  const _LessonTile({
    super.key,
    required this.lesson,
    required this.bookId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = lesson.status == 'published';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    lesson.title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _MediaChip(
                    icon: Icons.videocam_outlined,
                    active: lesson.hasVideo && !lesson.audioOnly),
                const SizedBox(width: AppSpacing.xs),
                _MediaChip(
                    icon: Icons.audiotrack_outlined,
                    active: lesson.hasAudio),
                const SizedBox(width: AppSpacing.xs),
                _MediaChip(
                    icon: Icons.picture_as_pdf_outlined,
                    active: lesson.hasPdf),
                const Spacer(),
                Switch(
                  value: isPublished,
                  activeThumbColor: scheme.primary,
                  onChanged: (v) => context
                      .read<AdminLessonListCubit>()
                      .togglePublish(lesson.id, v),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.push(
                        '/admin/books/$bookId/lessons/${lesson.id}/edit');
                    onRefresh();
                  },
                  tooltip: 'تعديل',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'حذف',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل تريد حذف درس "${lesson.title}"؟ سيتم حذف أسئلة الاختبار القصير أيضاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AdminLessonListCubit>().delete(lesson.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _MediaChip({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Icon(icon, size: 16, color: color);
  }
}
