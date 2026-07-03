// test/features/qa/qa_repository_test.dart
//
// Unit tests for QaRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (askQuestion → AuthFailure)
//   • PostgrestException mapping → ServerFailure
//   • StudentQuestionEntity.fromJson correctness (pure parse)
//   • CC-22: getBookQuestions uses student_questions_public (no user_id)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/features/qa/data/qa_repository.dart';
import 'package:sheikhy_app/models/student_question_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------
class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _offlineState = ConnectivityState(isOffline: true);
const _onlineState = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late QaRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = QaRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // askQuestion
  // -------------------------------------------------------------------------
  group('askQuestion', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.askQuestion(
        bookId: 'book-id',
        lessonId: 'lesson-id',
        questionText: 'ما الفرق بين النية والإرادة؟',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.askQuestion(
        bookId: 'book-id',
        lessonId: 'lesson-id',
        questionText: 'سؤال؟',
      );

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'insert failed'),
      );

      final result = await repo.askQuestion(
        bookId: 'book-id',
        lessonId: 'lesson-id',
        questionText: 'سؤال؟',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getBookQuestions — CC-22: reads student_questions_public
  // -------------------------------------------------------------------------
  group('getBookQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getBookQuestions('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'view error'),
      );

      final result = await repo.getBookQuestions('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries student_questions_public not student_questions', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'ok'),
      );

      await repo.getBookQuestions('book-id');

      // Verifies it calls from('student_questions_public') — CC-22
      verify(() => client.from('student_questions_public')).called(1);
      verifyNever(() => client.from('student_questions'));
    });
  });

  // -------------------------------------------------------------------------
  // StudentQuestionEntity.fromJson — pure parse tests
  // -------------------------------------------------------------------------
  group('StudentQuestionEntity.fromJson', () {
    test('parses a pending question correctly', () {
      final json = {
        'id': 'sq1',
        'book_id': 'b1',
        'lesson_id': 'l1',
        'question_text': 'ما الفرق بين النية والإرادة؟',
        'answer_text': null,
        'status': 'pending',
        'answered_at': null,
        'created_at': '2024-01-15T10:00:00.000Z',
        // CC-22: no user_id field — student_questions_public omits it
      };

      final entity = StudentQuestionEntity.fromJson(json);

      expect(entity.id, 'sq1');
      expect(entity.bookId, 'b1');
      expect(entity.lessonId, 'l1');
      expect(entity.questionText, 'ما الفرق بين النية والإرادة؟');
      expect(entity.answerText, isNull);
      expect(entity.status, 'pending');
      expect(entity.answeredAt, isNull);
      expect(entity.isAnswered, false);
    });

    test('parses an answered question correctly', () {
      final json = {
        'id': 'sq2',
        'book_id': 'b1',
        'lesson_id': 'l1',
        'question_text': 'سؤال آخر؟',
        'answer_text': 'الجواب هنا',
        'status': 'answered',
        'answered_at': '2024-01-16T12:00:00.000Z',
        'created_at': '2024-01-15T08:00:00.000Z',
      };

      final entity = StudentQuestionEntity.fromJson(json);

      expect(entity.answerText, 'الجواب هنا');
      expect(entity.status, 'answered');
      expect(entity.isAnswered, true);
      expect(entity.answeredAt, isNotNull);
    });

    test('createdAt is parsed as DateTime', () {
      final json = {
        'id': 'sq3',
        'book_id': 'b1',
        'lesson_id': 'l1',
        'question_text': 'سؤال؟',
        'answer_text': null,
        'status': 'pending',
        'answered_at': null,
        'created_at': '2024-06-01T00:00:00.000Z',
      };

      final entity = StudentQuestionEntity.fromJson(json);

      expect(entity.createdAt, DateTime.parse('2024-06-01T00:00:00.000Z'));
    });
  });
}
