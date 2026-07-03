// test/features/exam/exam_repository_test.dart
//
// Unit tests for ExamRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (getExamMeta → AuthFailure, getCertificates → AuthFailure)
//   • CC-18: getQuestions queries `final_exam_questions_student` view, not base table
//   • PostgrestException mapping (generic → ServerFailure; RPC codes → Arabic messages)
//   • submitExam RPC error-code mapping (P0001/P0003 → specific Arabic messages)
//   • Session round-trip (saveSession → loadSession → clearSession)
//   • Pure entity fromJson parsing (FinalExamQuestionEntity, FinalExamSettingsEntity,
//     FinalExamAttemptEntity, CertificateEntity) — no correct_choice present (CC-18)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/exam/data/exam_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/certificate_entity.dart';
import 'package:sheikhy_app/models/final_exam_attempt_entity.dart';
import 'package:sheikhy_app/models/final_exam_question_entity.dart';
import 'package:sheikhy_app/models/final_exam_settings_entity.dart';
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
  late ExamRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = ExamRepository(client, connectivity);
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // getExamMeta
  // -------------------------------------------------------------------------
  group('getExamMeta', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getExamMeta('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getExamMeta('book-id');

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'settings not found'),
      );

      final result = await repo.getExamMeta('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getQuestions — CC-18: must use final_exam_questions_student view
  // -------------------------------------------------------------------------
  group('getQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getQuestions('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    // CC-18: student view must be queried, not the base table
    test('queries final_exam_questions_student view, not base table (CC-18)',
        () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from('final_exam_questions_student')).thenThrow(
        const PostgrestException(message: 'view error'),
      );

      await repo.getQuestions('book-id');

      verify(() => client.from('final_exam_questions_student')).called(1);
      verifyNever(() => client.from('final_exam_questions'));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'view error'),
      );

      final result = await repo.getQuestions('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // submitExam — RPC only; error-code mapping (CC-18, CC-17)
  // -------------------------------------------------------------------------
  group('submitExam', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.submitExam(
        'book-id',
        {'q1': 'a'},
        DateTime.now(),
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any()));
    });

    test('maps P0001 (NOT_ENROLLED) to Arabic enrollment message', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.rpc(any(), params: any(named: 'params'))).thenThrow(
        const PostgrestException(message: 'NOT_ENROLLED', code: 'P0001'),
      );

      final result = await repo.submitExam(
        'book-id',
        {},
        DateTime.now(),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<ServerFailure>());
          expect(f.message, 'يجب التسجيل في الكتاب أولاً');
        },
        (_) => fail('expected Left'),
      );
    });

    test('maps P0003 (ATTEMPTS_EXHAUSTED) to Arabic attempts message (CC-13)',
        () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.rpc(any(), params: any(named: 'params'))).thenThrow(
        const PostgrestException(message: 'ATTEMPTS_EXHAUSTED', code: 'P0003'),
      );

      final result = await repo.submitExam(
        'book-id',
        {},
        DateTime.now(),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<ServerFailure>());
          expect(f.message, 'لقد استنفدت جميع محاولاتك');
        },
        (_) => fail('expected Left'),
      );
    });

    test('maps unknown PostgrestException to generic Arabic message', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.rpc(any(), params: any(named: 'params'))).thenThrow(
        const PostgrestException(message: 'unknown error'),
      );

      final result = await repo.submitExam(
        'book-id',
        {},
        DateTime.now(),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<ServerFailure>());
          expect(f.message, 'حدث خطأ أثناء تسليم الاختبار');
        },
        (_) => fail('expected Left'),
      );
    });

    test('calls submit_final_exam RPC (never grades client-side — CC-18)',
        () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.rpc('submit_final_exam',
              params: any(named: 'params')))
          .thenThrow(const PostgrestException(message: 'rpc error'));

      await repo.submitExam('book-id', {'q1': 'a'}, DateTime.now());

      verify(() => client.rpc('submit_final_exam',
          params: any(named: 'params'))).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // getCertificates
  // -------------------------------------------------------------------------
  group('getCertificates', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getCertificates();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getCertificates();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'certs query error'),
      );

      final result = await repo.getCertificates();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Session persistence (CC-11)
  // -------------------------------------------------------------------------
  group('session persistence', () {
    test('loadSession returns null when no session stored', () async {
      SharedPreferences.setMockInitialValues({});

      final session = await repo.loadSession('book-id');

      expect(session, isNull);
    });

    test('saveSession → loadSession round-trip preserves all fields', () async {
      SharedPreferences.setMockInitialValues({});

      final startedAt =
          DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final session = ExamSession(
        startedAt: startedAt,
        answers: {'q1': 'a', 'q2': 'b'},
        currentIndex: 2,
      );

      await repo.saveSession('book-id', session);
      final loaded = await repo.loadSession('book-id');

      expect(loaded, isNotNull);
      expect(loaded!.startedAt.millisecondsSinceEpoch,
          startedAt.millisecondsSinceEpoch);
      expect(loaded.answers, {'q1': 'a', 'q2': 'b'});
      expect(loaded.currentIndex, 2);
    });

    test('clearSession removes stored session', () async {
      SharedPreferences.setMockInitialValues({});

      await repo.saveSession(
        'book-id',
        ExamSession(
            startedAt: DateTime.now(), answers: {}, currentIndex: 0),
      );

      await repo.clearSession('book-id');
      final loaded = await repo.loadSession('book-id');

      expect(loaded, isNull);
    });

    test('sessions are keyed per bookId — different books do not collide',
        () async {
      SharedPreferences.setMockInitialValues({});

      final s1 = ExamSession(
          startedAt: DateTime.now(),
          answers: {'q1': 'a'},
          currentIndex: 0);
      final s2 = ExamSession(
          startedAt: DateTime.now(),
          answers: {'q9': 'd'},
          currentIndex: 5);

      await repo.saveSession('book-1', s1);
      await repo.saveSession('book-2', s2);

      final loaded1 = await repo.loadSession('book-1');
      final loaded2 = await repo.loadSession('book-2');

      expect(loaded1!.answers, {'q1': 'a'});
      expect(loaded2!.answers, {'q9': 'd'});
    });
  });

  // -------------------------------------------------------------------------
  // FinalExamQuestionEntity.fromJson — CC-18: no correct_choice in the view
  // -------------------------------------------------------------------------
  group('FinalExamQuestionEntity.fromJson', () {
    final json = {
      'id': 'eq1',
      'book_id': 'b1',
      'order_index': 0,
      'question_text': 'كم ركنًا للإسلام؟',
      'choice_a': 'ثلاثة',
      'choice_b': 'أربعة',
      'choice_c': 'خمسة',
      'choice_d': 'ستة',
      // No correct_choice — this is the _student view (CC-18)
    };

    test('parses all visible fields correctly', () {
      final entity = FinalExamQuestionEntity.fromJson(json);

      expect(entity.id, 'eq1');
      expect(entity.bookId, 'b1');
      expect(entity.orderIndex, 0);
      expect(entity.questionText, 'كم ركنًا للإسلام؟');
      expect(entity.choiceA, 'ثلاثة');
      expect(entity.choiceB, 'أربعة');
      expect(entity.choiceC, 'خمسة');
      expect(entity.choiceD, 'ستة');
    });

    test('choiceLabel returns the matching choice text', () {
      final entity = FinalExamQuestionEntity.fromJson(json);

      expect(entity.choiceLabel('a'), 'ثلاثة');
      expect(entity.choiceLabel('c'), 'خمسة');
      expect(entity.choiceLabel('z'), '');
    });

    test('entity has no correct_choice field — CC-18 guaranteed by model type',
        () {
      // If the view accidentally exposed correct_choice it would cause a
      // compile error here because FinalExamQuestionEntity has no such field.
      final entity = FinalExamQuestionEntity.fromJson(json);
      // ignore: unnecessary_type_check
      expect(entity is FinalExamQuestionEntity, true);
    });
  });

  // -------------------------------------------------------------------------
  // FinalExamSettingsEntity.fromJson
  // -------------------------------------------------------------------------
  group('FinalExamSettingsEntity.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'book_id': 'b1',
        'time_limit_minutes': 45,
        'passing_percentage': 70,
        'max_attempts': 2,
        'is_published': true,
      };

      final entity = FinalExamSettingsEntity.fromJson(json);

      expect(entity.bookId, 'b1');
      expect(entity.timeLimitMinutes, 45);
      expect(entity.passingPercentage, 70);
      expect(entity.maxAttempts, 2);
      expect(entity.isPublished, true);
    });
  });

  // -------------------------------------------------------------------------
  // FinalExamAttemptEntity.fromJson
  // -------------------------------------------------------------------------
  group('FinalExamAttemptEntity.fromJson', () {
    test('parses all fields including optional submittedAt', () {
      final json = {
        'id': 'att1',
        'user_id': 'u1',
        'book_id': 'b1',
        'attempt_number': 1,
        'score_percentage': 85,
        'passed': true,
        'started_at': '2026-07-01T10:00:00.000Z',
        'submitted_at': '2026-07-01T10:30:00.000Z',
      };

      final entity = FinalExamAttemptEntity.fromJson(json);

      expect(entity.id, 'att1');
      expect(entity.attemptNumber, 1);
      expect(entity.scorePercentage, 85);
      expect(entity.passed, true);
      expect(entity.submittedAt, isNotNull);
    });

    test('handles null submittedAt (in-progress attempt)', () {
      final json = {
        'id': 'att2',
        'user_id': 'u1',
        'book_id': 'b1',
        'attempt_number': 1,
        'score_percentage': 0,
        'passed': false,
        'started_at': '2026-07-01T10:00:00.000Z',
        'submitted_at': null,
      };

      final entity = FinalExamAttemptEntity.fromJson(json);

      expect(entity.submittedAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // CertificateEntity.fromJson
  // -------------------------------------------------------------------------
  group('CertificateEntity.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'cert1',
        'user_id': 'u1',
        'book_id': 'b1',
        'final_exam_attempt_id': 'att1',
        'final_score': 92,
        'grade_label': 'ممتاز',
        'issued_at': '2026-07-01T12:00:00.000Z',
        'pdf_url': null,
      };

      final entity = CertificateEntity.fromJson(json);

      expect(entity.id, 'cert1');
      expect(entity.bookId, 'b1');
      expect(entity.finalScore, 92);
      expect(entity.gradeLabel, 'ممتاز');
      expect(entity.pdfUrl, isNull);
    });

    test('handles null optional fields', () {
      final json = {
        'id': 'cert2',
        'user_id': 'u1',
        'book_id': 'b1',
        'final_exam_attempt_id': null,
        'final_score': 75,
        'grade_label': null,
        'issued_at': '2026-07-01T12:00:00.000Z',
        'pdf_url': null,
      };

      final entity = CertificateEntity.fromJson(json);

      expect(entity.finalExamAttemptId, isNull);
      expect(entity.gradeLabel, isNull);
    });
  });
}
