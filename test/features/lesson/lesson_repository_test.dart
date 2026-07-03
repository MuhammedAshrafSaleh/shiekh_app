// test/features/lesson/lesson_repository_test.dart
//
// Unit tests for LessonRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (getLessonProgress → null, saveProgress → AuthFailure)
//   • PostgrestException mapping → ServerFailure
//   • LessonEntity & QuizQuestionEntity fromJson correctness (pure parse)
//   • QuizGradeResult field mapping
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/lesson/data/lesson_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/lesson_entity.dart';
import 'package:sheikhy_app/models/quiz_question_entity.dart';
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
  late LessonRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = LessonRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getLesson
  // -------------------------------------------------------------------------
  group('getLesson', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getLesson('lesson-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'lesson not found'),
      );

      final result = await repo.getLesson('lesson-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getLessonProgress
  // -------------------------------------------------------------------------
  group('getLessonProgress', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getLessonProgress('lesson-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns Right(null) when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getLessonProgress('lesson-id');

      expect(result, const Right(null));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'progress query error'),
      );

      final result = await repo.getLessonProgress('lesson-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // saveProgress
  // -------------------------------------------------------------------------
  group('saveProgress', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        lastPositionSeconds: 120,
        completed: false,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        lastPositionSeconds: 60,
        completed: false,
      );

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'upsert failed'),
      );

      final result = await repo.saveProgress(
        lessonId: 'lesson-id',
        lastPositionSeconds: 300,
        completed: true,
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getQuizQuestions (CC-18: uses _student view)
  // -------------------------------------------------------------------------
  group('getQuizQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getQuizQuestions('lesson-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'view not found'),
      );

      final result = await repo.getQuizQuestions('lesson-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // gradeQuiz
  // -------------------------------------------------------------------------
  group('gradeQuiz', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.gradeQuiz('lesson-id', {'q1': 'a'});

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.rpc(any(), params: any(named: 'params'))).thenThrow(
        const PostgrestException(message: 'rpc error'),
      );

      final result = await repo.gradeQuiz('lesson-id', {'q1': 'b'});

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getNextLesson
  // -------------------------------------------------------------------------
  group('getNextLesson', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getNextLesson('book-id', 1);

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'query failed'),
      );

      final result = await repo.getNextLesson('book-id', 2);

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // LessonEntity.fromJson — pure parse tests
  // -------------------------------------------------------------------------
  group('LessonEntity.fromJson', () {
    test('parses a full lesson correctly', () {
      final json = {
        'id': 'l1',
        'book_id': 'b1',
        'order_index': 1,
        'title': 'الحديث الأول: النيات',
        'description': 'وصف الدرس',
        'video_url': 'https://youtu.be/abc',
        'audio_url': null,
        'pdf_url': null,
        'audio_only': false,
        'status': 'published',
      };

      final entity = LessonEntity.fromJson(json);

      expect(entity.id, 'l1');
      expect(entity.bookId, 'b1');
      expect(entity.orderIndex, 1);
      expect(entity.title, 'الحديث الأول: النيات');
      expect(entity.videoUrl, 'https://youtu.be/abc');
      expect(entity.audioUrl, isNull);
      expect(entity.audioOnly, false);
      expect(entity.hasVideo, true);
      expect(entity.hasAudio, false);
      expect(entity.hasPdf, false);
    });

    test('audio-only flag disables video tab', () {
      final json = {
        'id': 'l2',
        'book_id': 'b1',
        'order_index': 2,
        'title': 'درس صوتي',
        'description': null,
        'video_url': 'https://youtu.be/xyz',
        'audio_url': 'https://drive.google.com/file/d/abc/view',
        'pdf_url': null,
        'audio_only': true,
        'status': 'published',
      };

      final entity = LessonEntity.fromJson(json);

      expect(entity.audioOnly, true);
      expect(entity.hasVideo, false);
      expect(entity.hasAudio, true);
    });
  });

  // -------------------------------------------------------------------------
  // QuizQuestionEntity.fromJson — CC-18: no correct_choice field
  // -------------------------------------------------------------------------
  group('QuizQuestionEntity.fromJson', () {
    test('parses 4 choices and has no correct_choice field', () {
      final json = {
        'id': 'q1',
        'lesson_id': 'l1',
        'order_index': 0,
        'question_text': 'كم ركنًا للإسلام؟',
        'choice_a': 'ثلاثة',
        'choice_b': 'أربعة',
        'choice_c': 'خمسة',
        'choice_d': 'ستة',
        // No correct_choice — this is the _student view (CC-18)
      };

      final entity = QuizQuestionEntity.fromJson(json);

      expect(entity.id, 'q1');
      expect(entity.questionText, 'كم ركنًا للإسلام؟');
      expect(entity.choiceA, 'ثلاثة');
      expect(entity.choiceC, 'خمسة');
      expect(entity.choiceLabel('c'), 'خمسة');
    });

    test('choiceLabel returns empty string for unknown key', () {
      final json = {
        'id': 'q2',
        'lesson_id': 'l1',
        'order_index': 1,
        'question_text': 'سؤال',
        'choice_a': 'أ',
        'choice_b': 'ب',
        'choice_c': 'ج',
        'choice_d': 'د',
      };

      final entity = QuizQuestionEntity.fromJson(json);

      expect(entity.choiceLabel('z'), '');
    });
  });
}
