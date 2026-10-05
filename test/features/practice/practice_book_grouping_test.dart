// test/features/practice/practice_book_grouping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/features/practice/logic/practice_book_grouping.dart';
import 'package:sheikhy_app/models/practice_eligible_lesson_entity.dart';

PracticeEligibleLessonEntity _lesson(String id, String book, {int q = 10}) =>
    PracticeEligibleLessonEntity(
      lessonId: id,
      lessonTitle: 'درس $id',
      bookTitle: book,
      questionCount: q,
    );

void main() {
  group('groupLessonsByBook', () {
    test('empty input → empty groups', () {
      expect(groupLessonsByBook(const []), isEmpty);
    });

    test('groups by book, preserving incoming order', () {
      final lessons = [
        _lesson('a1', 'الكتاب الأول'),
        _lesson('a2', 'الكتاب الأول'),
        _lesson('b1', 'الكتاب الثاني'),
      ];

      final groups = groupLessonsByBook(lessons);

      expect(groups, hasLength(2));
      expect(groups[0].bookTitle, 'الكتاب الأول');
      expect(groups[0].lessonIds, ['a1', 'a2']);
      expect(groups[0].lessonCount, 2);
      expect(groups[1].bookTitle, 'الكتاب الثاني');
      expect(groups[1].lessonIds, ['b1']);
    });

    test('book order follows first appearance (RPC order), not sorted', () {
      final lessons = [_lesson('z1', 'ياء'), _lesson('a1', 'ألف')];
      final groups = groupLessonsByBook(lessons);
      expect(groups.map((g) => g.bookTitle).toList(), ['ياء', 'ألف']);
    });

    test('each group lesson list is unmodifiable', () {
      final groups = groupLessonsByBook([_lesson('a1', 'كتاب')]);
      expect(
        () => groups.first.lessons.add(_lesson('x', 'كتاب')),
        throwsUnsupportedError,
      );
    });
  });
}
