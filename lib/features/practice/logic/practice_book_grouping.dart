// lib/features/practice/logic/practice_book_grouping.dart
import 'package:equatable/equatable.dart';

import '../../../models/practice_eligible_lesson_entity.dart';

/// A book and its eligible lessons, for the grouped setup list.
class PracticeBookGroup extends Equatable {
  final String bookTitle;
  final List<PracticeEligibleLessonEntity> lessons;

  const PracticeBookGroup({required this.bookTitle, required this.lessons});

  int get lessonCount => lessons.length;

  List<String> get lessonIds => [for (final l in lessons) l.lessonId];

  @override
  List<Object?> get props => [bookTitle, lessons];
}

/// Groups eligible lessons by their book, preserving the incoming order
/// (`get_practice_eligible_lessons` already returns them ordered by book then
/// lesson order_index, so book order = first-encounter order, and each book's
/// lessons keep their order). Pure — no sorting, no DB.
List<PracticeBookGroup> groupLessonsByBook(
  List<PracticeEligibleLessonEntity> lessons,
) {
  final order = <String>[];
  final byBook = <String, List<PracticeEligibleLessonEntity>>{};
  for (final lesson in lessons) {
    byBook
        .putIfAbsent(lesson.bookTitle, () {
          order.add(lesson.bookTitle);
          return <PracticeEligibleLessonEntity>[];
        })
        .add(lesson);
  }
  return [
    for (final title in order)
      PracticeBookGroup(
        bookTitle: title,
        lessons: List.unmodifiable(byBook[title]!),
      ),
  ];
}
