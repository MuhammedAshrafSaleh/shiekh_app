// test/features/admin/admin_phase7_cubits_test.dart
//
// Cubit unit tests for Phase 7 admin authoring — covers state sequences for:
//   • AdminLessonListCubit  (load, togglePublish, delete, CC-5 reorder)
//   • AdminLessonFormCubit  (load new/existing, save create/update,
//                            addQuizQuestion, updateQuizQuestion, deleteQuizQuestion)
//   • AdminExamCubit        (load, saveSettings CC-14/CC-16, addQuestion,
//                            updateQuestion, deleteQuestion, importFromBank)
//   • AdminQaCubit          (load pending+answered, answerQuestion CC-22)
//   • AdminStatsCubit       (load lessons+stats+questions)
//   • AdminNotificationsCubit (load, send, delete)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/exam/cubit/admin_exam_cubit.dart';
import 'package:sheikhy_app/features/admin/exam/cubit/admin_exam_state.dart';
import 'package:sheikhy_app/features/admin/exam/data/admin_exam_repository.dart';
import 'package:sheikhy_app/features/admin/lessons/cubit/admin_lesson_cubit.dart';
import 'package:sheikhy_app/features/admin/lessons/cubit/admin_lesson_state.dart';
import 'package:sheikhy_app/features/admin/lessons/data/admin_lesson_repository.dart';
import 'package:sheikhy_app/features/admin/notifications/cubit/admin_notifications_cubit.dart';
import 'package:sheikhy_app/features/admin/notifications/cubit/admin_notifications_state.dart';
import 'package:sheikhy_app/features/admin/notifications/data/admin_notifications_repository.dart';
import 'package:sheikhy_app/features/admin/qa/cubit/admin_qa_cubit.dart';
import 'package:sheikhy_app/features/admin/qa/cubit/admin_qa_state.dart';
import 'package:sheikhy_app/features/admin/qa/data/admin_qa_repository.dart';
import 'package:sheikhy_app/features/admin/stats/cubit/admin_stats_cubit.dart';
import 'package:sheikhy_app/features/admin/stats/cubit/admin_stats_state.dart';
import 'package:sheikhy_app/features/admin/stats/data/admin_stats_repository.dart';
import 'package:sheikhy_app/models/admin_final_exam_question_entity.dart';
import 'package:sheikhy_app/models/admin_quiz_question_entity.dart';
import 'package:sheikhy_app/models/final_exam_settings_entity.dart';
import 'package:sheikhy_app/models/lesson_entity.dart';
import 'package:sheikhy_app/models/notification_entity.dart';
import 'package:sheikhy_app/models/student_question_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mock repositories
// ---------------------------------------------------------------------------
class _MockLessonRepo extends Mock implements AdminLessonRepository {}

class _MockExamRepo extends Mock implements AdminExamRepository {}

class _MockQaRepo extends Mock implements AdminQaRepository {}

class _MockStatsRepo extends Mock implements AdminStatsRepository {}

class _MockNotifRepo extends Mock implements AdminNotificationsRepository {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------
const _serverFailure = ServerFailure('خطأ في الخادم');

const _lesson = LessonEntity(
  id: 'les-1',
  bookId: 'book-1',
  orderIndex: 1,
  title: 'الدرس الأول',
  audioOnly: false,
  status: 'draft',
);

const _lesson2 = LessonEntity(
  id: 'les-2',
  bookId: 'book-1',
  orderIndex: 2,
  title: 'الدرس الثاني',
  audioOnly: false,
  status: 'published',
);

const _quizQ = AdminQuizQuestionEntity(
  id: 'qq-1',
  lessonId: 'les-1',
  orderIndex: 0,
  questionText: 'ما معنى الإيمان؟',
  choiceA: 'أ',
  choiceB: 'ب',
  choiceC: 'ج',
  choiceD: 'د',
  correctChoice: 'a',
);

const _examQ = AdminFinalExamQuestionEntity(
  id: 'eq-1',
  bookId: 'book-1',
  orderIndex: 0,
  questionText: 'سؤال الاختبار النهائي',
  choiceA: 'أ',
  choiceB: 'ب',
  choiceC: 'ج',
  choiceD: 'د',
  correctChoice: 'b',
);

const _settings = FinalExamSettingsEntity(
  bookId: 'book-1',
  timeLimitMinutes: 60,
  passingPercentage: 70,
  maxAttempts: 3,
  isPublished: false,
);

final _studentQ = StudentQuestionEntity(
  id: 'sq-1',
  bookId: 'book-1',
  lessonId: 'les-1',
  questionText: 'سؤال الطالب',
  status: 'pending',
  createdAt: DateTime(2024),
);

final _answeredQ = StudentQuestionEntity(
  id: 'sq-2',
  bookId: 'book-1',
  lessonId: 'les-1',
  questionText: 'سؤال آخر',
  answerText: 'إجابة الشيخ',
  status: 'answered',
  answeredAt: DateTime(2024, 2),
  createdAt: DateTime(2024),
);

final _notification = NotificationEntity(
  id: 'notif-1',
  type: 'general',
  title: 'إشعار جديد',
  body: 'نص الإشعار',
  sendAt: DateTime(2024, 6),
  createdAt: DateTime(2024, 6),
  isRead: false,
);

final _bookStats = BookStats(
  totalStudents: 20,
  completedStudents: 5,
  completionRate: 25.0,
  avgScore: 78.5,
  totalAttempts: 15,
  enrollmentTrend: [],
);

// ===========================================================================
// AdminLessonListCubit
// ===========================================================================
void main() {
  group('AdminLessonListCubit', () {
    late _MockLessonRepo repo;
    late AdminLessonListCubit cubit;

    setUp(() {
      repo = _MockLessonRepo();
      cubit = AdminLessonListCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ─────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded on success', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson, _lesson2]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonListLoading>(),
            isA<AdminLessonListLoaded>(),
          ]),
        );
        await cubit.load('book-1');
        await expectation;

        expect((cubit.state as AdminLessonListLoaded).lessons, [
          _lesson,
          _lesson2,
        ]);
      });

      test('emits Loading then Empty when no lessons', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonListLoading>(),
            isA<AdminLessonListEmpty>(),
          ]),
        );
        await cubit.load('book-1');
        await expectation;
      });

      test('emits Loading then Error on failure', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonListLoading>(),
            isA<AdminLessonListError>(),
          ]),
        );
        await cubit.load('book-1');
        await expectation;

        expect(
          (cubit.state as AdminLessonListError).message,
          _serverFailure.message,
        );
      });
    });

    // ── togglePublish ─────────────────────────────────────────────────────────
    group('togglePublish', () {
      test('refreshes list (emits Loading → Loaded) on success', () async {
        when(
          () => repo.togglePublish(any(), any()),
        ).thenAnswer((_) async => const Right(unit));
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson2]));

        // Prime _bookId
        cubit.load('book-1');

        final expectation = expectLater(
          cubit.stream,
          emitsThrough(isA<AdminLessonListLoaded>()),
        );
        await cubit.togglePublish('les-1', true);
        await expectation;
      });

      test('emits Error on failure', () async {
        when(
          () => repo.togglePublish(any(), any()),
        ).thenAnswer((_) async => const Left(_serverFailure));
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson]));

        cubit.load('book-1');

        final expectation = expectLater(
          cubit.stream,
          emitsThrough(isA<AdminLessonListError>()),
        );
        await cubit.togglePublish('les-1', true);
        await expectation;
      });
    });

    // ── delete ────────────────────────────────────────────────────────────────
    group('delete', () {
      test('refreshes list on success', () async {
        when(
          () => repo.deleteLesson(any()),
        ).thenAnswer((_) async => const Right(unit));
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([]));

        cubit.load('book-1');

        final expectation = expectLater(
          cubit.stream,
          emitsThrough(isA<AdminLessonListEmpty>()),
        );
        await cubit.delete('les-1');
        await expectation;
      });

      test('emits Error on failure', () async {
        when(
          () => repo.deleteLesson(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson]));

        cubit.load('book-1');

        final expectation = expectLater(
          cubit.stream,
          emitsThrough(isA<AdminLessonListError>()),
        );
        await cubit.delete('les-1');
        await expectation;
      });
    });

    // ── CC-5 reorder ──────────────────────────────────────────────────────────
    group('reorder (CC-5)', () {
      test('returns true on successful transactional reorder', () async {
        when(
          () => repo.reorderLessons(any()),
        ).thenAnswer((_) async => const Right(unit));

        final ok = await cubit.reorder([
          (id: 'les-2', orderIndex: 1),
          (id: 'les-1', orderIndex: 2),
        ]);
        expect(ok, isTrue);
      });

      test('returns false on reorder failure', () async {
        when(
          () => repo.reorderLessons(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final ok = await cubit.reorder([(id: 'les-1', orderIndex: 1)]);
        expect(ok, isFalse);
      });
    });
  });

  // ===========================================================================
  // AdminLessonFormCubit
  // ===========================================================================
  group('AdminLessonFormCubit', () {
    late _MockLessonRepo repo;
    late AdminLessonFormCubit cubit;

    setUp(() {
      repo = _MockLessonRepo();
      cubit = AdminLessonFormCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load (new lesson) ─────────────────────────────────────────────────────
    group('load (new lesson)', () {
      test(
        'emits Loading then Loaded with null lesson and empty quiz',
        () async {
          final expectation = expectLater(
            cubit.stream,
            emitsInOrder([
              isA<AdminLessonFormLoading>(),
              isA<AdminLessonFormLoaded>(),
            ]),
          );
          await cubit.load();
          await expectation;

          final loaded = cubit.state as AdminLessonFormLoaded;
          expect(loaded.lesson, isNull);
          expect(loaded.quizQuestions, isEmpty);
        },
      );
    });

    // ── load (existing lesson) ────────────────────────────────────────────────
    group('load (existing lesson)', () {
      test(
        'emits Loading then Loaded with lesson and quiz questions',
        () async {
          when(
            () => repo.getLesson(any()),
          ).thenAnswer((_) async => const Right(_lesson));
          when(
            () => repo.getQuizQuestions(any()),
          ).thenAnswer((_) async => const Right([_quizQ]));

          final expectation = expectLater(
            cubit.stream,
            emitsInOrder([
              isA<AdminLessonFormLoading>(),
              isA<AdminLessonFormLoaded>(),
            ]),
          );
          await cubit.load(lessonId: 'les-1');
          await expectation;

          final loaded = cubit.state as AdminLessonFormLoaded;
          expect(loaded.lesson, _lesson);
          expect(loaded.quizQuestions, [_quizQ]);
        },
      );

      test('emits Error when getLesson fails', () async {
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonFormLoading>(),
            isA<AdminLessonFormError>(),
          ]),
        );
        await cubit.load(lessonId: 'les-1');
        await expectation;
      });

      test('emits Error when getQuizQuestions fails', () async {
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Right(_lesson));
        when(
          () => repo.getQuizQuestions(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonFormLoading>(),
            isA<AdminLessonFormError>(),
          ]),
        );
        await cubit.load(lessonId: 'les-1');
        await expectation;
      });
    });

    // ── save (create) ─────────────────────────────────────────────────────────
    group('save (create)', () {
      test('emits Saving then Saved on success', () async {
        when(
          () => repo.createLesson(
            bookId: any(named: 'bookId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            videoUrl: any(named: 'videoUrl'),
            audioUrl: any(named: 'audioUrl'),
            pdfUrl: any(named: 'pdfUrl'),
            audioOnly: any(named: 'audioOnly'),
            status: any(named: 'status'),
          ),
        ).thenAnswer((_) async => const Right(_lesson));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonFormSaving>(),
            isA<AdminLessonFormSaved>(),
          ]),
        );
        await cubit.save(
          bookId: 'book-1',
          title: 'الدرس الأول',
          audioOnly: false,
          status: 'draft',
        );
        await expectation;

        expect((cubit.state as AdminLessonFormSaved).lesson, _lesson);
      });

      test('emits Saving then Error on failure', () async {
        when(
          () => repo.createLesson(
            bookId: any(named: 'bookId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            videoUrl: any(named: 'videoUrl'),
            audioUrl: any(named: 'audioUrl'),
            pdfUrl: any(named: 'pdfUrl'),
            audioOnly: any(named: 'audioOnly'),
            status: any(named: 'status'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonFormSaving>(),
            isA<AdminLessonFormError>(),
          ]),
        );
        await cubit.save(
          bookId: 'book-1',
          title: 'درس',
          audioOnly: false,
          status: 'draft',
        );
        await expectation;
      });
    });

    // ── save (update) ─────────────────────────────────────────────────────────
    group('save (update)', () {
      test('emits Saving then Saved on success', () async {
        when(
          () => repo.updateLesson(
            id: any(named: 'id'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            videoUrl: any(named: 'videoUrl'),
            audioUrl: any(named: 'audioUrl'),
            pdfUrl: any(named: 'pdfUrl'),
            audioOnly: any(named: 'audioOnly'),
            status: any(named: 'status'),
          ),
        ).thenAnswer((_) async => const Right(_lesson));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminLessonFormSaving>(),
            isA<AdminLessonFormSaved>(),
          ]),
        );
        await cubit.save(
          lessonId: 'les-1',
          bookId: 'book-1',
          title: 'الدرس المحدّث',
          audioOnly: false,
          status: 'published',
        );
        await expectation;
      });
    });

    // ── addQuizQuestion ───────────────────────────────────────────────────────
    group('addQuizQuestion', () {
      test('appends question to Loaded state on success', () async {
        // Prime with a loaded state
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Right(_lesson));
        when(
          () => repo.getQuizQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load(lessonId: 'les-1');

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
        ).thenAnswer((_) async => const Right(_quizQ));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminLessonFormLoaded>()),
        );
        await cubit.addQuizQuestion(
          lessonId: 'les-1',
          questionText: 'ما معنى الإيمان؟',
          choiceA: 'أ',
          choiceB: 'ب',
          choiceC: 'ج',
          choiceD: 'د',
          correctChoice: 'a',
        );
        await expectation;

        final loaded = cubit.state as AdminLessonFormLoaded;
        expect(loaded.quizQuestions, contains(_quizQ));
      });

      test('emits Error on failure', () async {
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Right(_lesson));
        when(
          () => repo.getQuizQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load(lessonId: 'les-1');

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
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminLessonFormError>()),
        );
        await cubit.addQuizQuestion(
          lessonId: 'les-1',
          questionText: 'سؤال',
          choiceA: 'أ',
          choiceB: 'ب',
          choiceC: 'ج',
          choiceD: 'د',
          correctChoice: 'a',
        );
        await expectation;
      });
    });

    // ── deleteQuizQuestion ────────────────────────────────────────────────────
    group('deleteQuizQuestion', () {
      test('removes question from Loaded state on success', () async {
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Right(_lesson));
        when(
          () => repo.getQuizQuestions(any()),
        ).thenAnswer((_) async => const Right([_quizQ]));
        await cubit.load(lessonId: 'les-1');

        when(
          () => repo.deleteQuizQuestion(any()),
        ).thenAnswer((_) async => const Right(unit));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminLessonFormLoaded>()),
        );
        await cubit.deleteQuizQuestion('qq-1');
        await expectation;

        final loaded = cubit.state as AdminLessonFormLoaded;
        expect(loaded.quizQuestions, isEmpty);
      });

      test('emits Error on failure', () async {
        when(
          () => repo.getLesson(any()),
        ).thenAnswer((_) async => const Right(_lesson));
        when(
          () => repo.getQuizQuestions(any()),
        ).thenAnswer((_) async => const Right([_quizQ]));
        await cubit.load(lessonId: 'les-1');

        when(
          () => repo.deleteQuizQuestion(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminLessonFormError>()),
        );
        await cubit.deleteQuizQuestion('qq-1');
        await expectation;
      });
    });
  });

  // ===========================================================================
  // AdminExamCubit
  // ===========================================================================
  group('AdminExamCubit', () {
    late _MockExamRepo repo;
    late AdminExamCubit cubit;

    setUp(() {
      repo = _MockExamRepo();
      cubit = AdminExamCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ──────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded with settings and questions', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([_examQ]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamLoading>(), isA<AdminExamLoaded>()]),
        );
        await cubit.load('book-1');
        await expectation;

        final loaded = cubit.state as AdminExamLoaded;
        expect(loaded.settings, _settings);
        expect(loaded.questions, [_examQ]);
      });

      test('emits Loaded with null settings when no settings exist', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamLoading>(), isA<AdminExamLoaded>()]),
        );
        await cubit.load('book-1');
        await expectation;

        expect((cubit.state as AdminExamLoaded).settings, isNull);
      });

      test('emits Error when getSettings fails', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamLoading>(), isA<AdminExamError>()]),
        );
        await cubit.load('book-1');
        await expectation;
      });

      test('emits Error when getQuestions fails', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamLoading>(), isA<AdminExamError>()]),
        );
        await cubit.load('book-1');
        await expectation;
      });
    });

    // ── saveSettings — CC-14/CC-16 ────────────────────────────────────────────
    group('saveSettings (CC-14/CC-16)', () {
      test('reloads (emits Loading → Loaded) on success', () async {
        // Prime book id
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([_examQ]));
        await cubit.load('book-1');

        when(
          () => repo.upsertSettings(
            bookId: any(named: 'bookId'),
            timeLimitMinutes: any(named: 'timeLimitMinutes'),
            passingPercentage: any(named: 'passingPercentage'),
            maxAttempts: any(named: 'maxAttempts'),
            isPublished: any(named: 'isPublished'),
          ),
        ).thenAnswer((_) async => const Right(_settings));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminExamSaving>(),
            isA<AdminExamLoading>(),
            isA<AdminExamLoaded>(),
          ]),
        );
        await cubit.saveSettings(
          timeLimitMinutes: 60,
          passingPercentage: 70,
          maxAttempts: 3,
          isPublished: true,
        );
        await expectation;
      });

      test('emits Error on failure', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load('book-1');

        when(
          () => repo.upsertSettings(
            bookId: any(named: 'bookId'),
            timeLimitMinutes: any(named: 'timeLimitMinutes'),
            passingPercentage: any(named: 'passingPercentage'),
            maxAttempts: any(named: 'maxAttempts'),
            isPublished: any(named: 'isPublished'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamSaving>(), isA<AdminExamError>()]),
        );
        await cubit.saveSettings(
          timeLimitMinutes: 60,
          passingPercentage: 70,
          maxAttempts: 3,
          isPublished: false,
        );
        await expectation;
      });
    });

    // ── addQuestion ───────────────────────────────────────────────────────────
    group('addQuestion', () {
      test('appends question to Loaded state on success', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load('book-1');

        when(
          () => repo.createQuestion(
            bookId: any(named: 'bookId'),
            questionText: any(named: 'questionText'),
            choiceA: any(named: 'choiceA'),
            choiceB: any(named: 'choiceB'),
            choiceC: any(named: 'choiceC'),
            choiceD: any(named: 'choiceD'),
            correctChoice: any(named: 'correctChoice'),
            sourceQuizQuestionId: any(named: 'sourceQuizQuestionId'),
          ),
        ).thenAnswer((_) async => const Right(_examQ));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminExamLoaded>()),
        );
        await cubit.addQuestion(
          questionText: 'سؤال',
          choiceA: 'أ',
          choiceB: 'ب',
          choiceC: 'ج',
          choiceD: 'د',
          correctChoice: 'b',
        );
        await expectation;

        final loaded = cubit.state as AdminExamLoaded;
        expect(loaded.questions, contains(_examQ));
      });

      test('emits Error on failure', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load('book-1');

        when(
          () => repo.createQuestion(
            bookId: any(named: 'bookId'),
            questionText: any(named: 'questionText'),
            choiceA: any(named: 'choiceA'),
            choiceB: any(named: 'choiceB'),
            choiceC: any(named: 'choiceC'),
            choiceD: any(named: 'choiceD'),
            correctChoice: any(named: 'correctChoice'),
            sourceQuizQuestionId: any(named: 'sourceQuizQuestionId'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminExamError>()),
        );
        await cubit.addQuestion(
          questionText: 'سؤال',
          choiceA: 'أ',
          choiceB: 'ب',
          choiceC: 'ج',
          choiceD: 'د',
          correctChoice: 'b',
        );
        await expectation;
      });
    });

    // ── deleteQuestion ────────────────────────────────────────────────────────
    group('deleteQuestion', () {
      test('removes question from Loaded state on success', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([_examQ]));
        await cubit.load('book-1');

        when(
          () => repo.deleteQuestion(any()),
        ).thenAnswer((_) async => const Right(unit));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminExamLoaded>()),
        );
        await cubit.deleteQuestion('eq-1');
        await expectation;

        final loaded = cubit.state as AdminExamLoaded;
        expect(loaded.questions, isEmpty);
      });

      test('emits Error on failure', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([_examQ]));
        await cubit.load('book-1');

        when(
          () => repo.deleteQuestion(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminExamError>()),
        );
        await cubit.deleteQuestion('eq-1');
        await expectation;
      });
    });

    // ── importFromBank ────────────────────────────────────────────────────────
    group('importFromBank', () {
      test('reloads after successful import', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load('book-1');

        when(
          () => repo.importBankQuestions(
            bookId: any(named: 'bookId'),
            questions: any(named: 'questions'),
          ),
        ).thenAnswer((_) async => const Right(1));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminExamLoading>(), isA<AdminExamLoaded>()]),
        );
        await cubit.importFromBank([_quizQ]);
        await expectation;
      });

      test('emits Error on import failure', () async {
        when(
          () => repo.getSettings(any()),
        ).thenAnswer((_) async => const Right(_settings));
        when(
          () => repo.getQuestions(any()),
        ).thenAnswer((_) async => const Right([]));
        await cubit.load('book-1');

        when(
          () => repo.importBankQuestions(
            bookId: any(named: 'bookId'),
            questions: any(named: 'questions'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminExamError>()),
        );
        await cubit.importFromBank([_quizQ]);
        await expectation;
      });
    });
  });

  // ===========================================================================
  // AdminQaCubit
  // ===========================================================================
  group('AdminQaCubit', () {
    late _MockQaRepo repo;
    late _MockRealtimeChannel channel;
    late AdminQaCubit cubit;

    setUp(() {
      repo = _MockQaRepo();
      channel = _MockRealtimeChannel();
      cubit = AdminQaCubit(repo);

      when(() => channel.unsubscribe()).thenAnswer((_) async => 'ok');
      when(() => repo.subscribeToNewQuestions(any())).thenReturn(channel);
    });

    tearDown(() => cubit.close());

    // ── load ──────────────────────────────────────────────────────────────────
    group('load', () {
      test(
        'emits Loading then Loaded with pending and answered tabs',
        () async {
          when(
            () => repo.getQuestions(
              status: 'pending',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => Right([_studentQ]));
          when(
            () => repo.getQuestions(
              status: 'answered',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => Right([_answeredQ]));

          final expectation = expectLater(
            cubit.stream,
            emitsInOrder([isA<AdminQaLoading>(), isA<AdminQaLoaded>()]),
          );
          await cubit.load();
          await expectation;

          final loaded = cubit.state as AdminQaLoaded;
          expect(loaded.pending, [_studentQ]);
          expect(loaded.answered, [_answeredQ]);
        },
      );

      test('emits Error when pending fetch fails', () async {
        when(
          () => repo.getQuestions(
            status: 'pending',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminQaLoading>(), isA<AdminQaError>()]),
        );
        await cubit.load();
        await expectation;
      });

      test('emits Error when answered fetch fails', () async {
        when(
          () => repo.getQuestions(
            status: 'pending',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => Right([_studentQ]));
        when(
          () => repo.getQuestions(
            status: 'answered',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminQaLoading>(), isA<AdminQaError>()]),
        );
        await cubit.load();
        await expectation;
      });
    });

    // ── answerQuestion ────────────────────────────────────────────────────────
    group('answerQuestion', () {
      test('returns true and reloads on success', () async {
        when(
          () => repo.answerQuestion(
            questionId: any(named: 'questionId'),
            answerText: any(named: 'answerText'),
          ),
        ).thenAnswer((_) async => Right(_answeredQ));
        when(
          () => repo.getQuestions(
            status: 'pending',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Right([]));
        when(
          () => repo.getQuestions(
            status: 'answered',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => Right([_answeredQ]));

        final ok = await cubit.answerQuestion(
          questionId: 'sq-1',
          answerText: 'إجابة الشيخ',
        );
        expect(ok, isTrue);
      });

      test('returns false and emits Error on failure', () async {
        when(
          () => repo.answerQuestion(
            questionId: any(named: 'questionId'),
            answerText: any(named: 'answerText'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminQaError>()),
        );
        final ok = await cubit.answerQuestion(
          questionId: 'sq-1',
          answerText: 'إجابة',
        );
        await expectation;
        expect(ok, isFalse);
        expect((cubit.state as AdminQaError).message, _serverFailure.message);
      });
    });
  });

  // ===========================================================================
  // AdminStatsCubit
  // ===========================================================================
  group('AdminStatsCubit', () {
    late _MockStatsRepo repo;
    late AdminStatsCubit cubit;

    setUp(() {
      repo = _MockStatsRepo();
      cubit = AdminStatsCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ──────────────────────────────────────────────────────────────────
    group('load', () {
      test(
        'emits Loading then Loaded with lessons, stats, and questions',
        () async {
          when(
            () => repo.getLessons(any()),
          ).thenAnswer((_) async => const Right([_lesson, _lesson2]));
          when(
            () => repo.getBookStats(any()),
          ).thenAnswer((_) async => Right(_bookStats));
          when(
            () => repo.getBookQuestions(any()),
          ).thenAnswer((_) async => Right([_studentQ]));

          final expectation = expectLater(
            cubit.stream,
            emitsInOrder([isA<AdminStatsLoading>(), isA<AdminStatsLoaded>()]),
          );
          await cubit.load('book-1');
          await expectation;

          final loaded = cubit.state as AdminStatsLoaded;
          expect(loaded.lessons, [_lesson, _lesson2]);
          expect(loaded.stats.totalStudents, 20);
          expect(loaded.questions, [_studentQ]);
        },
      );

      test('emits Error when getLessons fails', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminStatsLoading>(), isA<AdminStatsError>()]),
        );
        await cubit.load('book-1');
        await expectation;
      });

      test('emits Error when getBookStats fails', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson]));
        when(
          () => repo.getBookStats(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminStatsLoading>(), isA<AdminStatsError>()]),
        );
        await cubit.load('book-1');
        await expectation;
      });

      test('emits Error when getBookQuestions fails', () async {
        when(
          () => repo.getLessons(any()),
        ).thenAnswer((_) async => const Right([_lesson]));
        when(
          () => repo.getBookStats(any()),
        ).thenAnswer((_) async => Right(_bookStats));
        when(
          () => repo.getBookQuestions(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([isA<AdminStatsLoading>(), isA<AdminStatsError>()]),
        );
        await cubit.load('book-1');
        await expectation;
      });
    });
  });

  // ===========================================================================
  // AdminNotificationsCubit
  // ===========================================================================
  group('AdminNotificationsCubit', () {
    late _MockNotifRepo repo;
    late AdminNotificationsCubit cubit;

    setUp(() {
      repo = _MockNotifRepo();
      cubit = AdminNotificationsCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ──────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded on success', () async {
        when(
          () => repo.getNotifications(),
        ).thenAnswer((_) async => Right([_notification]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminNotificationsLoading>(),
            isA<AdminNotificationsLoaded>(),
          ]),
        );
        await cubit.load();
        await expectation;

        final loaded = cubit.state as AdminNotificationsLoaded;
        expect(loaded.notifications, [_notification]);
      });

      test('emits Loading then Empty when list is empty', () async {
        when(
          () => repo.getNotifications(),
        ).thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminNotificationsLoading>(),
            isA<AdminNotificationsEmpty>(),
          ]),
        );
        await cubit.load();
        await expectation;
      });

      test('emits Loading then Error on failure', () async {
        when(
          () => repo.getNotifications(),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminNotificationsLoading>(),
            isA<AdminNotificationsError>(),
          ]),
        );
        await cubit.load();
        await expectation;

        expect(
          (cubit.state as AdminNotificationsError).message,
          _serverFailure.message,
        );
      });
    });

    // ── send ──────────────────────────────────────────────────────────────────
    group('send', () {
      test(
        'returns true and emits Sending → Sent → Loaded on success',
        () async {
          when(
            () => repo.createNotification(
              type: any(named: 'type'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              linkUrl: any(named: 'linkUrl'),
              sendAt: any(named: 'sendAt'),
            ),
          ).thenAnswer((_) async => Right(_notification));
          when(
            () => repo.getNotifications(),
          ).thenAnswer((_) async => Right([_notification]));

          final expectation = expectLater(
            cubit.stream,
            emitsInOrder([
              isA<AdminNotificationsSending>(),
              isA<AdminNotificationsSent>(),
              isA<AdminNotificationsLoading>(),
              isA<AdminNotificationsLoaded>(),
            ]),
          );
          final ok = await cubit.send(
            type: 'general',
            title: 'إشعار',
            body: 'نص',
            sendAt: DateTime(2024, 6),
          );
          await expectation;
          expect(ok, isTrue);
        },
      );

      test('returns false and emits Sending → Error on failure', () async {
        when(
          () => repo.createNotification(
            type: any(named: 'type'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            linkUrl: any(named: 'linkUrl'),
            sendAt: any(named: 'sendAt'),
          ),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminNotificationsSending>(),
            isA<AdminNotificationsError>(),
          ]),
        );
        final ok = await cubit.send(
          type: 'general',
          title: 'إشعار',
          body: 'نص',
          sendAt: DateTime(2024, 6),
        );
        await expectation;
        expect(ok, isFalse);
      });
    });

    // ── delete ────────────────────────────────────────────────────────────────
    group('delete', () {
      test('reloads list on success', () async {
        when(
          () => repo.deleteNotification(any()),
        ).thenAnswer((_) async => const Right(unit));
        when(
          () => repo.getNotifications(),
        ).thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminNotificationsLoading>(),
            isA<AdminNotificationsEmpty>(),
          ]),
        );
        await cubit.delete('notif-1');
        await expectation;
      });

      test('emits Error on failure', () async {
        when(
          () => repo.deleteNotification(any()),
        ).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminNotificationsError>()),
        );
        await cubit.delete('notif-1');
        await expectation;
      });
    });
  });
}
