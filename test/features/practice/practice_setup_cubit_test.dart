// test/features/practice/practice_setup_cubit_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/practice/cubit/practice_setup_cubit.dart';
import 'package:sheikhy_app/features/practice/cubit/practice_setup_state.dart';
import 'package:sheikhy_app/features/practice/data/practice_repository.dart';
import 'package:sheikhy_app/features/practice/logic/practice_distribution.dart';
import 'package:sheikhy_app/models/practice_attempt_summary_entity.dart';
import 'package:sheikhy_app/models/practice_eligible_lesson_entity.dart';

class _MockPracticeRepository extends Mock implements PracticeRepository {}

PracticeEligibleLessonEntity _lesson(String id, String book, {int q = 10}) =>
    PracticeEligibleLessonEntity(
      lessonId: id,
      lessonTitle: 'درس $id',
      bookTitle: book,
      questionCount: q,
    );

// Book A: a1,a2,a3 (10 each) · Book B: b1,b2 (10 each) → 50 total available.
final _lessons = [
  _lesson('a1', 'الكتاب الأول'),
  _lesson('a2', 'الكتاب الأول'),
  _lesson('a3', 'الكتاب الأول'),
  _lesson('b1', 'الكتاب الثاني'),
  _lesson('b2', 'الكتاب الثاني'),
];

void main() {
  late _MockPracticeRepository repo;
  late PracticeSetupCubit cubit;

  setUp(() async {
    repo = _MockPracticeRepository();
    when(
      () => repo.getEligibleLessons(),
    ).thenAnswer((_) async => Right(_lessons));
    when(
      () => repo.getHistory(),
    ).thenAnswer((_) async => Right(<PracticeAttemptSummaryEntity>[]));
    cubit = PracticeSetupCubit(repo);
    await cubit.load();
  });

  tearDown(() => cubit.close());

  PracticeSetupLoaded loaded() => cubit.state as PracticeSetupLoaded;

  test('load emits Loaded with 2 book groups, nothing selected/expanded', () {
    expect(loaded().bookGroups, hasLength(2));
    expect(loaded().selectedLessonIds, isEmpty);
    expect(loaded().expandedBooks, isEmpty);
    expect(loaded().canStart, isFalse);
  });

  test('load emits Error when eligible-lessons fetch fails', () async {
    when(
      () => repo.getEligibleLessons(),
    ).thenAnswer((_) async => Left(ServerFailure('boom')));
    await cubit.load();
    expect(cubit.state, isA<PracticeSetupError>());
  });

  test('toggleBookExpanded flips a book open then closed', () {
    cubit.toggleBookExpanded('الكتاب الأول');
    expect(loaded().expandedBooks, {'الكتاب الأول'});
    cubit.toggleBookExpanded('الكتاب الأول');
    expect(loaded().expandedBooks, isEmpty);
  });

  test('selectAllInBook adds every lesson of that book (global selection)', () {
    cubit.selectAllInBook(['a1', 'a2', 'a3']);
    expect(loaded().selectedLessonIds, {'a1', 'a2', 'a3'});
    expect(loaded().totalAvailable, 30);
  });

  test('selection mixes across books', () {
    cubit.selectAllInBook(['a1', 'a2', 'a3']);
    cubit.selectAllInBook(['b1', 'b2']);
    expect(loaded().selectedLessonIds, {'a1', 'a2', 'a3', 'b1', 'b2'});
    expect(loaded().totalAvailable, 50);
    expect(loaded().canStart, isTrue);
  });

  test('clearBook removes only that book, leaving others selected', () {
    cubit.selectAllInBook(['a1', 'a2', 'a3', 'b1', 'b2']);
    cubit.clearBook(['a1', 'a2', 'a3']);
    expect(loaded().selectedLessonIds, {'b1', 'b2'});
    expect(loaded().totalAvailable, 20);
  });

  test('count is clamped up to the minimum when enough is selected', () {
    // 50 available → maxCount 50; default count is the 20 minimum.
    cubit.selectAllInBook(['a1', 'a2', 'a3', 'b1', 'b2']);
    cubit.setCount(45);
    expect(loaded().questionCount, 45);
  });

  test('count re-clamps down when selection shrinks below current count', () {
    cubit.selectAllInBook(['a1', 'a2', 'a3', 'b1', 'b2']); // 50 avail
    cubit.setCount(45);
    expect(loaded().questionCount, 45);

    // Drop to 30 available (book A only) → count must re-clamp to 30.
    cubit.clearBook(['b1', 'b2']);
    expect(loaded().totalAvailable, 30);
    expect(loaded().questionCount, 30);
  });

  test('setCount cannot exceed maxCount or go below the minimum', () {
    cubit.selectAllInBook(['a1', 'a2', 'a3']); // 30 available
    cubit.setCount(999);
    expect(loaded().questionCount, 30);
    cubit.setCount(1);
    expect(loaded().questionCount, kMinPracticeQuestions);
  });
}
