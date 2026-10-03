// test/features/admin/admin_lesson_delete_test.dart
//
// Covers the quiz-question delete fix:
//   • Cubit: a failed delete keeps the loaded list (transientError), a
//     successful delete removes the item.
//   • Repository: Postgres errors are mapped to Arabic (FK 23503 vs generic),
//     never surfaced raw.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/lessons/cubit/admin_lesson_cubit.dart';
import 'package:sheikhy_app/features/admin/lessons/cubit/admin_lesson_state.dart';
import 'package:sheikhy_app/features/admin/lessons/data/admin_lesson_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/admin_quiz_question_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AdminLessonRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _online = ConnectivityState(isOffline: false);
const _offline = ConnectivityState(isOffline: true);

AdminQuizQuestionEntity _q(String id) => AdminQuizQuestionEntity(
  id: id,
  lessonId: 'L1',
  orderIndex: 0,
  questionText: 'سؤال $id',
  choiceA: 'أ',
  choiceB: 'ب',
  choiceC: 'ج',
  choiceD: 'د',
  correctChoice: 'a',
);

void main() {
  // -------------------------------------------------------------------------
  // Cubit — delete keeps/removes
  // -------------------------------------------------------------------------
  group('AdminLessonFormCubit.deleteQuizQuestion', () {
    late _MockRepo repo;
    late AdminLessonFormCubit cubit;

    setUp(() async {
      repo = _MockRepo();
      cubit = AdminLessonFormCubit(repo);

      // Seed a Loaded state with one question via addQuizQuestion (no getLesson
      // fixture needed: load() with null lessonId emits an empty Loaded).
      when(
        () => repo.createQuizQuestion(
          lessonId: any(named: 'lessonId'),
          questionText: any(named: 'questionText'),
          choiceA: any(named: 'choiceA'),
          choiceB: any(named: 'choiceB'),
          choiceC: any(named: 'choiceC'),
          choiceD: any(named: 'choiceD'),
          correctChoice: any(named: 'correctChoice'),
        ),
      ).thenAnswer((_) async => Right(_q('q1')));

      await cubit.load(); // Loaded(lesson: null, quizQuestions: [])
      await cubit.addQuizQuestion(
        lessonId: 'L1',
        questionText: 'سؤال q1',
        choiceA: 'أ',
        choiceB: 'ب',
        choiceC: 'ج',
        choiceD: 'د',
        correctChoice: 'a',
      );
    });

    tearDown(() => cubit.close());

    test('failure keeps the list visible and sets a transient error', () async {
      final loadedBefore = cubit.state as AdminLessonFormLoaded;
      expect(loadedBefore.quizQuestions, hasLength(1));

      when(
        () => repo.deleteQuizQuestion(any()),
      ).thenAnswer((_) async => Left(ServerFailure('لا يمكن حذف هذا السؤال')));

      await cubit.deleteQuizQuestion('q1');

      final state = cubit.state;
      expect(state, isA<AdminLessonFormLoaded>());
      final loaded = state as AdminLessonFormLoaded;
      expect(loaded.quizQuestions, hasLength(1), reason: 'list not wiped');
      expect(loaded.quizQuestions.first.id, 'q1');
      expect(loaded.transientError, isNotNull);
    });

    test('success removes the question from the list', () async {
      when(
        () => repo.deleteQuizQuestion(any()),
      ).thenAnswer((_) async => const Right(unit));

      await cubit.deleteQuizQuestion('q1');

      final loaded = cubit.state as AdminLessonFormLoaded;
      expect(loaded.quizQuestions, isEmpty);
      expect(loaded.transientError, isNull);
    });

    test('success sets a one-shot success message', () async {
      when(
        () => repo.deleteQuizQuestion(any()),
      ).thenAnswer((_) async => const Right(unit));

      await cubit.deleteQuizQuestion('q1');

      final loaded = cubit.state as AdminLessonFormLoaded;
      expect(loaded.transientSuccess, 'تم حذف السؤال');
      expect(loaded.transientError, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Repository — error mapping
  // -------------------------------------------------------------------------
  group('AdminLessonRepository.deleteQuizQuestion error mapping', () {
    late _MockSupabaseClient client;
    late _MockConnectivityCubit connectivity;
    late AdminLessonRepository repo;

    setUp(() {
      client = _MockSupabaseClient();
      connectivity = _MockConnectivityCubit();
      repo = AdminLessonRepository(client, connectivity);
    });

    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteQuizQuestion('q1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('maps FK violation (23503) to a specific Arabic message', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'fk violation', code: '23503'),
      );

      final result = await repo.deleteQuizQuestion('q1');

      result.fold((f) {
        expect(f, isA<ServerFailure>());
        expect(f.message, 'لا يمكن حذف هذا السؤال لأنه مُستخدم في مكان آخر.');
      }, (_) => fail('expected Left'));
    });

    test('maps any other Postgres error to a generic Arabic message', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'boom', code: '500'));

      final result = await repo.deleteQuizQuestion('q1');

      result.fold((f) {
        expect(f, isA<ServerFailure>());
        expect(f.message, 'تعذّر حذف السؤال، حاول مرة أخرى.');
      }, (_) => fail('expected Left'));
    });
  });
}
