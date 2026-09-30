// test/core/widgets/bank_import_cubit_test.dart
//
// Unit tests for BankImportCubit — the drill-down picker state: lazy per-lesson
// loading + caching, selection persisting across lessons, the select-all
// toggle, and per-lesson selected-count derivation.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/core/widgets/bank_import_cubit.dart';
import 'package:sheikhy_app/core/widgets/bank_import_state.dart';
import 'package:sheikhy_app/features/admin/shared/data/question_bank_repository.dart';
import 'package:sheikhy_app/models/admin_quiz_question_entity.dart';
import 'package:sheikhy_app/models/bank_lesson_summary_entity.dart';

class _MockRepo extends Mock implements QuestionBankRepository {}

AdminQuizQuestionEntity _q(String id, String lessonId) =>
    AdminQuizQuestionEntity(
      id: id,
      lessonId: lessonId,
      orderIndex: 0,
      questionText: 'س $id',
      choiceA: 'أ',
      choiceB: 'ب',
      choiceC: 'ج',
      choiceD: 'د',
      correctChoice: 'a',
    );

void main() {
  late _MockRepo repo;

  final lessons = [
    const BankLessonSummaryEntity(
      lessonId: 'A',
      title: 'الدرس أ',
      orderIndex: 0,
      approvedCount: 2,
    ),
    const BankLessonSummaryEntity(
      lessonId: 'B',
      title: 'الدرس ب',
      orderIndex: 1,
      approvedCount: 1,
    ),
  ];
  final qA1 = _q('a1', 'A');
  final qA2 = _q('a2', 'A');
  final qB1 = _q('b1', 'B');

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.getBankLessonSummaries(any()),
    ).thenAnswer((_) async => Right(lessons));
    when(
      () => repo.getLessonBankQuestions('A'),
    ).thenAnswer((_) async => Right([qA1, qA2]));
    when(
      () => repo.getLessonBankQuestions('B'),
    ).thenAnswer((_) async => Right([qB1]));
  });

  BankImportCubit build() => BankImportCubit(repo, 'book-1');

  test('loadLessons populates the lessons list', () async {
    final cubit = build();
    await cubit.loadLessons();

    expect(cubit.state.lessonsStatus, BankLessonsStatus.loaded);
    expect(cubit.state.lessons, lessons);
  });

  test('loadLessons error path surfaces the message', () async {
    when(
      () => repo.getBankLessonSummaries(any()),
    ).thenAnswer((_) async => Left(ServerFailure('خطأ')));
    final cubit = build();
    await cubit.loadLessons();

    expect(cubit.state.lessonsStatus, BankLessonsStatus.error);
    expect(cubit.state.lessonsError, 'خطأ');
  });

  test('openLesson fetches once then serves from cache', () async {
    final cubit = build();
    await cubit.openLesson('A');
    expect(cubit.state.currentQuestions, [qA1, qA2]);

    cubit.backToLessons();
    await cubit.openLesson('A'); // cache hit — no second fetch

    verify(() => repo.getLessonBankQuestions('A')).called(1);
  });

  test('selection persists across lessons', () async {
    final cubit = build();
    await cubit.openLesson('A');
    cubit.toggle(qA1);
    cubit.backToLessons();
    await cubit.openLesson('B');
    cubit.toggle(qB1);

    expect(cubit.state.selected.keys, containsAll(['a1', 'b1']));
    expect(cubit.state.selectedCount, 2);
    expect(cubit.state.selectedCountForLesson('A'), 1);
    expect(cubit.state.selectedCountForLesson('B'), 1);
  });

  test('selectAllFiltered selects all then deselects on repeat', () async {
    final cubit = build();
    await cubit.openLesson('A');

    cubit.selectAllFiltered([qA1, qA2]);
    expect(cubit.state.selectedCount, 2);

    cubit.selectAllFiltered([qA1, qA2]);
    expect(cubit.state.selectedCount, 0);
  });

  test(
    'selectAllFiltered over a filtered subset leaves others untouched',
    () async {
      final cubit = build();
      await cubit.openLesson('A');
      cubit.toggle(qA2); // pre-selected

      // Filtered set is just [qA1]; not all selected → selects qA1, keeps qA2.
      cubit.selectAllFiltered([qA1]);
      expect(cubit.state.selected.keys, containsAll(['a1', 'a2']));
    },
  );

  test('toggle adds then removes', () async {
    final cubit = build();
    cubit.toggle(qA1);
    expect(cubit.state.selected.containsKey('a1'), true);
    cubit.toggle(qA1);
    expect(cubit.state.selected.containsKey('a1'), false);
  });
}
