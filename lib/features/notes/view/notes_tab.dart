// lib/features/notes/view/notes_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../models/lesson_with_progress_entity.dart';
import '../cubit/notes_cubit.dart';
import '../cubit/notes_state.dart';
import '../widgets/notes_lecture_tile.dart';

/// Level 1 — shows lectures that have at least one note, ordered by
/// lesson order_index. Tapping drills into Level 2 (a pushed route).
class NotesTab extends StatelessWidget {
  final String bookId;
  final List<LessonWithProgressEntity> lessons;

  const NotesTab({
    super.key,
    required this.bookId,
    required this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        return switch (state) {
          NotesInitial() || NotesLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          NotesError(:final message) => SheikhyErrorState(
            heading: 'تعذّر تحميل الملحوظات',
            message: message,
            onRetry: () =>
                context.read<NotesCubit>().loadBookNotes(bookId),
          ),
          NotesLoaded(:final notes) => _LevelOneList(
            bookId: bookId,
            lessons: lessons,
            notes: notes,
            onRetry: () =>
                context.read<NotesCubit>().loadBookNotes(bookId),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _LevelOneList extends StatelessWidget {
  final String bookId;
  final List<LessonWithProgressEntity> lessons;
  final List<dynamic> notes;
  final VoidCallback onRetry;

  const _LevelOneList({
    required this.bookId,
    required this.lessons,
    required this.notes,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Build note count per lessonId.
    final countByLesson = <String, int>{};
    for (final note in notes) {
      final lessonId = note.lessonId as String;
      countByLesson[lessonId] = (countByLesson[lessonId] ?? 0) + 1;
    }

    // Filter lessons that have notes, preserving order_index order.
    final lecturesWithNotes = lessons
        .where((l) => countByLesson.containsKey(l.lesson.id))
        .toList();

    if (lecturesWithNotes.isEmpty) {
      return const SheikhyEmptyState(
        icon: Icons.notes_outlined,
        heading: 'لا توجد ملحوظات',
        subtitle: 'أضف ملحوظة أثناء مشاهدة المحاضرة لتظهر هنا',
      );
    }

    return ListView.separated(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      itemCount: lecturesWithNotes.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppColors.border,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final item = lecturesWithNotes[index];
        final lesson = item.lesson;
        final count = countByLesson[lesson.id]!;

        return NotesLectureTile(
          title: lesson.title,
          noteCount: count,
          onTap: () => context.push(
            '/books/$bookId/notes/${lesson.id}',
            extra: lesson.title,
          ),
        );
      },
    );
  }
}
