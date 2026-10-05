// test/features/practice/practice_repository_test.dart
//
// Unit tests for PracticeRepository — covers for every method:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (AuthFailure) on authed methods
//   • PostgrestException mapping → Failure
// plus pure fromJson parsing for every practice entity (incl. the review
// tombstone shape and submit-error mapping).
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/features/practice/data/practice_repository.dart';
import 'package:sheikhy_app/models/practice_attempt_summary_entity.dart';
import 'package:sheikhy_app/models/practice_eligible_lesson_entity.dart';
import 'package:sheikhy_app/models/practice_lecture_breakdown.dart';
import 'package:sheikhy_app/models/practice_review_question.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';
}

const _offlineState = ConnectivityState(isOffline: true);
const _onlineState = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late PracticeRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = PracticeRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getEligibleLessons
  // -------------------------------------------------------------------------
  group('getEligibleLessons', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getEligibleLessons();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getEligibleLessons();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.rpc(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.rpc(any()),
      ).thenThrow(const PostgrestException(message: 'rpc error'));

      final result = await repo.getEligibleLessons();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getQuestionPool
  // -------------------------------------------------------------------------
  group('getQuestionPool', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getQuestionPool(['l1']);

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test(
      'returns Right(empty) for empty lesson list without querying',
      () async {
        when(() => connectivity.state).thenReturn(_onlineState);

        final result = await repo.getQuestionPool(const []);

        expect(result.isRight(), true);
        result.fold(
          (_) => fail('expected Right'),
          (list) => expect(list, isEmpty),
        );
        verifyNever(() => client.from(any()));
      },
    );

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'view error'));

      final result = await repo.getQuestionPool(['l1']);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // submitAttempt
  // -------------------------------------------------------------------------
  group('submitAttempt', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.submitAttempt(
        questionOrder: const ['q1'],
        answers: const {'q1': 'a'},
        durationSeconds: 60,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.submitAttempt(
        questionOrder: const ['q1'],
        answers: const {'q1': 'a'},
        durationSeconds: 60,
      );

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('maps NO_VALID_QUESTIONS to ValidationFailure', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'NO_VALID_QUESTIONS'));

      final result = await repo.submitAttempt(
        questionOrder: const ['q1'],
        answers: const {'q1': 'a'},
        durationSeconds: 60,
      );

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps TAMPERING to PermissionFailure', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'TAMPERING'));

      final result = await repo.submitAttempt(
        questionOrder: const ['q1'],
        answers: const {'q1': 'a'},
        durationSeconds: 60,
      );

      result.fold(
        (f) => expect(f, isA<PermissionFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps an unknown error to a generic ServerFailure', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'something odd'));

      final result = await repo.submitAttempt(
        questionOrder: const ['q1'],
        answers: const {'q1': 'a'},
        durationSeconds: 60,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getHistory
  // -------------------------------------------------------------------------
  group('getHistory', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getHistory();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getHistory();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'select error'));

      final result = await repo.getHistory();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getAttemptReview
  // -------------------------------------------------------------------------
  group('getAttemptReview', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getAttemptReview('a1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getAttemptReview('a1');

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
    });
  });

  // -------------------------------------------------------------------------
  // Entity parsing — pure
  // -------------------------------------------------------------------------
  group('PracticeEligibleLessonEntity.fromJson', () {
    test('parses fields', () {
      final e = PracticeEligibleLessonEntity.fromJson({
        'lesson_id': 'l1',
        'lesson_title': 'المحاضرة 1',
        'book_title': 'الكتاب',
        'question_count': 12,
      });
      expect(e.lessonId, 'l1');
      expect(e.lessonTitle, 'المحاضرة 1');
      expect(e.bookTitle, 'الكتاب');
      expect(e.questionCount, 12);
    });
  });

  group('PracticeLectureBreakdown.fromJson', () {
    test('parses fields', () {
      final b = PracticeLectureBreakdown.fromJson({
        'lesson_id': 'l1',
        'lesson_title': 'الدرس',
        'correct': 4,
        'total': 5,
      });
      expect(b.lessonId, 'l1');
      expect(b.correct, 4);
      expect(b.total, 5);
    });
  });

  group('PracticeAttemptSummaryEntity.fromJson', () {
    test('parses a full summary row', () {
      final s = PracticeAttemptSummaryEntity.fromJson({
        'id': 'att-1',
        'score_percentage': 80,
        'correct_count': 16,
        'total_count': 20,
        'lesson_ids': ['l1', 'l2'],
        'breakdown': [
          {'lesson_id': 'l1', 'lesson_title': 'د١', 'correct': 8, 'total': 10},
          {'lesson_id': 'l2', 'lesson_title': 'د٢', 'correct': 8, 'total': 10},
        ],
        'duration_seconds': 300,
        'time_limit_minutes': 30,
        'created_at': '2026-09-30T12:00:00.000Z',
      });

      expect(s.id, 'att-1');
      expect(s.scorePercentage, 80);
      expect(s.lectureCount, 2);
      expect(s.breakdown, hasLength(2));
      expect(s.durationSeconds, 300);
      expect(s.timeLimitMinutes, 30);
      expect(s.createdAt, DateTime.utc(2026, 9, 30, 12));
    });

    test('handles null time_limit_minutes (timer off)', () {
      final s = PracticeAttemptSummaryEntity.fromJson({
        'id': 'att-2',
        'score_percentage': 50,
        'correct_count': 10,
        'total_count': 20,
        'lesson_ids': ['l1'],
        'breakdown': [],
        'duration_seconds': 120,
        'time_limit_minutes': null,
        'created_at': '2026-09-30T12:00:00.000Z',
      });

      expect(s.timeLimitMinutes, isNull);
      expect(s.breakdown, isEmpty);
      expect(s.lectureCount, 1);
    });
  });

  group('PracticeReviewQuestion.fromJson', () {
    test('parses a normal graded question', () {
      final q = PracticeReviewQuestion.fromJson({
        'question_id': 'q1',
        'question_text': 'نص',
        'choice_a': 'أ',
        'choice_b': 'ب',
        'choice_c': 'ج',
        'choice_d': 'د',
        'correct_choice': 'b',
        'user_answer': 'a',
        'is_correct': false,
        'lesson_title': 'الدرس',
        'is_deleted': false,
      });

      expect(q.isDeleted, isFalse);
      expect(q.correctChoice, 'b');
      expect(q.userAnswer, 'a');
      expect(q.isCorrect, isFalse);
      expect(q.choiceText('b'), 'ب');
      expect(q.lessonTitle, 'الدرس');
    });

    test('parses a tombstone (deleted) question', () {
      final q = PracticeReviewQuestion.fromJson({
        'question_id': 'q-gone',
        'user_answer': 'c',
        'is_deleted': true,
      });

      expect(q.isDeleted, isTrue);
      expect(q.questionText, isNull);
      expect(q.correctChoice, isNull);
      expect(q.userAnswer, 'c');
      expect(q.isCorrect, isFalse);
      expect(q.choiceText('a'), isNull);
    });
  });
}
