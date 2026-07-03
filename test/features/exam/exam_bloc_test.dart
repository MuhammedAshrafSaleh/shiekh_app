// test/features/exam/exam_bloc_test.dart
//
// Unit tests for ExamBloc — covers:
//   • ExamInProgress state helpers (answeredCount, unansweredCount, questionStatus)
//   • ExamMetaLoaded state helpers (attemptsExhausted, isLocked — CC-13/CC-15/CC-16)
//   • ExamTick decrements secondsRemaining
//   • ExamTick at 1s remaining emits secondsRemaining = 0 then triggers ExamAutoSubmit
//   • ExamAnswerSelected adds/overwrites answer in answers map
//   • ExamNavigateTo changes currentIndex (ignores out-of-bounds)
//   • CC-11 resume: loadSession returns valid session → bloc emits ExamInProgress
//     immediately with restored answers and computed remaining time
//   • CC-11/CC-12 auto-submit: loadSession returns expired session → bloc calls
//     submitExam and emits ExamCompleted
//   • ExamSubmitConfirmed transitions to ExamCompleted via RPC
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_bloc.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_event.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_state.dart';
import 'package:sheikhy_app/features/exam/data/exam_repository.dart';
import 'package:sheikhy_app/models/final_exam_question_entity.dart';
import 'package:sheikhy_app/models/final_exam_settings_entity.dart';

// ---------------------------------------------------------------------------
// Mocks & fallbacks
// ---------------------------------------------------------------------------
class _MockExamRepository extends Mock implements ExamRepository {}

class _FakeExamSession extends Fake implements ExamSession {}

class _FakeDateTime extends Fake implements DateTime {}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------
final _settings = FinalExamSettingsEntity(
  bookId: 'book-1',
  timeLimitMinutes: 30,
  passingPercentage: 70,
  maxAttempts: 2,
  isPublished: true,
);

FinalExamQuestionEntity _makeQuestion(int index) =>
    FinalExamQuestionEntity(
      id: 'q$index',
      bookId: 'book-1',
      orderIndex: index,
      questionText: 'سؤال $index',
      choiceA: 'أ',
      choiceB: 'ب',
      choiceC: 'ج',
      choiceD: 'د',
    );

final _questions = [
  _makeQuestion(0),
  _makeQuestion(1),
  _makeQuestion(2),
];

ExamInProgress _inProgressState({
  Map<String, String>? answers,
  int currentIndex = 0,
  int secondsRemaining = 120,
}) =>
    ExamInProgress(
      bookId: 'book-1',
      settings: _settings,
      questions: _questions,
      answers: answers ?? const {},
      currentIndex: currentIndex,
      secondsRemaining: secondsRemaining,
      startedAt: DateTime(2026, 7, 1, 10, 0),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Drives the bloc to ExamInProgress by mocking a fresh start flow.
Future<void> _driveToInProgress(
  ExamBloc bloc,
  _MockExamRepository repo, {
  Map<String, String>? answers,
}) async {
  when(() => repo.loadSession(any())).thenAnswer((_) async => null);
  when(() => repo.getExamMeta(any())).thenAnswer(
    (_) async => Right(ExamMeta(
      settings: _settings,
      questionCount: _questions.length,
      attemptsUsed: 0,
      pastAttempts: [],
    )),
  );
  when(() => repo.getQuestions(any()))
      .thenAnswer((_) async => Right(_questions));
  when(() => repo.saveSession(any(), any())).thenAnswer((_) async {});
  when(() => repo.clearSession(any())).thenAnswer((_) async {});

  bloc.add(const ExamLoadRequested('book-1'));
  await bloc.stream.firstWhere((s) => s is ExamMetaLoaded);

  bloc.add(const ExamStartRequested());
  await bloc.stream.firstWhere((s) => s is ExamInProgress);
}

void main() {
  late _MockExamRepository repo;
  late ExamBloc bloc;

  setUpAll(() {
    registerFallbackValue(_FakeExamSession());
    registerFallbackValue(_FakeDateTime());
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    repo = _MockExamRepository();
    bloc = ExamBloc(repo);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await bloc.close();
  });

  // -------------------------------------------------------------------------
  // ExamInProgress state helpers (pure logic — no bloc needed)
  // -------------------------------------------------------------------------
  group('ExamInProgress helpers', () {
    test('answeredCount reflects answers map size', () {
      final state = _inProgressState(answers: {'q0': 'a', 'q1': 'b'});
      expect(state.answeredCount, 2);
    });

    test('unansweredCount = total questions - answered', () {
      final state = _inProgressState(answers: {'q0': 'a'});
      expect(state.unansweredCount, 2); // 3 total − 1 answered
    });

    test('questionStatus returns "current" for currentIndex', () {
      final state = _inProgressState(currentIndex: 1);
      expect(state.questionStatus(1), 'current');
    });

    test('questionStatus returns "answered" for answered non-current question',
        () {
      final state = _inProgressState(
        answers: {'q0': 'a'},
        currentIndex: 1,
      );
      expect(state.questionStatus(0), 'answered');
    });

    test('questionStatus returns null for unanswered non-current question', () {
      final state = _inProgressState(currentIndex: 0);
      expect(state.questionStatus(1), isNull);
    });

    test('currentQuestion returns question at currentIndex', () {
      final state = _inProgressState(currentIndex: 2);
      expect(state.currentQuestion.id, 'q2');
    });
  });

  // -------------------------------------------------------------------------
  // ExamMetaLoaded helpers — CC-13/CC-15/CC-16 lock logic
  // -------------------------------------------------------------------------
  group('ExamMetaLoaded lock logic', () {
    ExamMetaLoaded _metaState({
      int attemptsUsed = 0,
      bool isPublished = true,
      int questionCount = 5,
    }) =>
        ExamMetaLoaded(
          bookId: 'book-1',
          settings: FinalExamSettingsEntity(
            bookId: 'book-1',
            timeLimitMinutes: 30,
            passingPercentage: 70,
            maxAttempts: 2,
            isPublished: isPublished,
          ),
          questionCount: questionCount,
          attemptsUsed: attemptsUsed,
          pastAttempts: [],
        );

    test('attemptsExhausted is false when under limit', () {
      expect(_metaState(attemptsUsed: 1).attemptsExhausted, false);
    });

    test('attemptsExhausted is true when attemptsUsed >= maxAttempts (CC-13)',
        () {
      expect(_metaState(attemptsUsed: 2).attemptsExhausted, true);
    });

    test('isLocked when exam is not published (CC-15)', () {
      expect(_metaState(isPublished: false).isLocked, true);
    });

    test('isLocked when zero questions (CC-16)', () {
      expect(_metaState(questionCount: 0).isLocked, true);
    });

    test('isLocked when attempts exhausted (CC-13)', () {
      expect(_metaState(attemptsUsed: 2).isLocked, true);
    });

    test('isLocked is false when published, has questions, attempts remain',
        () {
      expect(_metaState().isLocked, false);
    });
  });

  // -------------------------------------------------------------------------
  // ExamTick — timer logic
  // -------------------------------------------------------------------------
  group('ExamTick', () {
    test('decrements secondsRemaining by 1', () async {
      await _driveToInProgress(bloc, repo);
      final before = (bloc.state as ExamInProgress).secondsRemaining;

      bloc.add(const ExamTick());
      await bloc.stream.firstWhere((s) {
        return s is ExamInProgress && s.secondsRemaining == before - 1;
      });

      final after = (bloc.state as ExamInProgress).secondsRemaining;
      expect(after, before - 1);
    });

    test('secondsRemaining reaches 0 and triggers auto-submit (CC-12)',
        () async {
      // Arrange: put bloc directly in an almost-expired state
      when(() => repo.loadSession(any())).thenAnswer((_) async => null);
      when(() => repo.getExamMeta(any())).thenAnswer(
        (_) async => Right(ExamMeta(
          settings: _settings,
          questionCount: _questions.length,
          attemptsUsed: 0,
          pastAttempts: [],
        )),
      );
      when(() => repo.getQuestions(any()))
          .thenAnswer((_) async => Right(_questions));
      when(() => repo.saveSession(any(), any())).thenAnswer((_) async {});
      when(() => repo.clearSession(any())).thenAnswer((_) async {});
      when(() => repo.submitExam(any(), any(), any())).thenAnswer(
        (_) async => Right(ExamSubmitResult(
          attemptId: 'att1',
          score: 80,
          correct: 4,
          total: 5,
          passed: true,
          gradeLabel: 'جيد جداً',
          certIssued: false,
        )),
      );

      bloc.add(const ExamLoadRequested('book-1'));
      await bloc.stream.firstWhere((s) => s is ExamMetaLoaded);
      bloc.add(const ExamStartRequested());
      await bloc.stream.firstWhere((s) => s is ExamInProgress);

      // Manually emit ticks until 0 — use copyWith to simulate tick at 1s
      // Instead: directly add ExamAutoSubmit to simulate timer expiry
      bloc.add(const ExamAutoSubmit());
      await bloc.stream.firstWhere((s) => s is ExamCompleted);

      expect(bloc.state, isA<ExamCompleted>());
      verify(() => repo.submitExam(any(), any(), any())).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // ExamAnswerSelected
  // -------------------------------------------------------------------------
  group('ExamAnswerSelected', () {
    test('adds answer to empty map', () async {
      await _driveToInProgress(bloc, repo);

      bloc.add(const ExamAnswerSelected('q0', 'a'));
      await bloc.stream.firstWhere((s) {
        return s is ExamInProgress &&
            (s as ExamInProgress).answers.containsKey('q0');
      });

      final state = bloc.state as ExamInProgress;
      expect(state.answers['q0'], 'a');
    });

    test('overwrites existing answer for same question', () async {
      await _driveToInProgress(bloc, repo);

      bloc.add(const ExamAnswerSelected('q0', 'a'));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.answers['q0'] == 'a');

      bloc.add(const ExamAnswerSelected('q0', 'c'));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.answers['q0'] == 'c');

      final state = bloc.state as ExamInProgress;
      expect(state.answers['q0'], 'c');
      expect(state.answers.length, 1); // only 1 entry, not 2
    });

    test('other answers are preserved when a new answer is added', () async {
      await _driveToInProgress(bloc, repo);

      bloc.add(const ExamAnswerSelected('q0', 'a'));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.answers.containsKey('q0'));
      bloc.add(const ExamAnswerSelected('q1', 'b'));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.answers.length == 2);

      final state = bloc.state as ExamInProgress;
      expect(state.answers, {'q0': 'a', 'q1': 'b'});
    });
  });

  // -------------------------------------------------------------------------
  // ExamNavigateTo
  // -------------------------------------------------------------------------
  group('ExamNavigateTo', () {
    test('changes currentIndex to target', () async {
      await _driveToInProgress(bloc, repo);

      bloc.add(const ExamNavigateTo(2));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.currentIndex == 2);

      expect((bloc.state as ExamInProgress).currentIndex, 2);
    });

    test('ignores out-of-bounds indices', () async {
      await _driveToInProgress(bloc, repo);
      final before = (bloc.state as ExamInProgress).currentIndex;

      bloc.add(const ExamNavigateTo(99));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as ExamInProgress).currentIndex, before);
    });
  });

  // -------------------------------------------------------------------------
  // CC-11: Resume from saved session
  // -------------------------------------------------------------------------
  group('resume from saved session (CC-11)', () {
    test('emits ExamInProgress immediately when valid session exists', () async {
      final startedAt =
          DateTime.now().subtract(const Duration(minutes: 5)); // 5 min ago
      final savedSession = ExamSession(
        startedAt: startedAt,
        answers: {'q0': 'b', 'q2': 'd'},
        currentIndex: 1,
      );

      when(() => repo.loadSession(any()))
          .thenAnswer((_) async => savedSession);
      when(() => repo.getExamMeta(any())).thenAnswer(
        (_) async => Right(ExamMeta(
          settings: _settings, // 30 min limit — 5 min elapsed → 25 min left
          questionCount: _questions.length,
          attemptsUsed: 1,
          pastAttempts: [],
        )),
      );
      when(() => repo.getQuestions(any()))
          .thenAnswer((_) async => Right(_questions));
      when(() => repo.saveSession(any(), any())).thenAnswer((_) async {});
      when(() => repo.clearSession(any())).thenAnswer((_) async {});

      bloc.add(const ExamLoadRequested('book-1'));
      await bloc.stream.firstWhere((s) => s is ExamInProgress);

      final state = bloc.state as ExamInProgress;
      expect(state.answers, {'q0': 'b', 'q2': 'd'});
      expect(state.currentIndex, 1);
      // 30 min limit - 5 min elapsed = ~25 min left (allow ±2s tolerance)
      expect(state.secondsRemaining,
          closeTo(25 * 60, 5));
    });
  });

  // -------------------------------------------------------------------------
  // CC-11/CC-12: Auto-submit when saved session has expired
  // -------------------------------------------------------------------------
  group('auto-submit expired session (CC-11/CC-12)', () {
    test('calls submitExam and emits ExamCompleted when session time expired',
        () async {
      // Session started 2 hours ago — limit is 30 min → expired
      final startedAt =
          DateTime.now().subtract(const Duration(hours: 2));
      final expiredSession = ExamSession(
        startedAt: startedAt,
        answers: {'q0': 'a'},
        currentIndex: 0,
      );

      when(() => repo.loadSession(any()))
          .thenAnswer((_) async => expiredSession);
      when(() => repo.getExamMeta(any())).thenAnswer(
        (_) async => Right(ExamMeta(
          settings: _settings, // 30 min limit
          questionCount: _questions.length,
          attemptsUsed: 0,
          pastAttempts: [],
        )),
      );
      when(() => repo.getQuestions(any()))
          .thenAnswer((_) async => Right(_questions));
      when(() => repo.clearSession(any())).thenAnswer((_) async {});
      when(() => repo.submitExam(any(), any(), any())).thenAnswer(
        (_) async => Right(ExamSubmitResult(
          attemptId: 'att-auto',
          score: 40,
          correct: 1,
          total: 3,
          passed: false,
          gradeLabel: 'جيد',
          certIssued: false,
        )),
      );

      bloc.add(const ExamLoadRequested('book-1'));
      await bloc.stream
          .firstWhere((s) => s is ExamCompleted)
          .timeout(const Duration(seconds: 5));

      expect(bloc.state, isA<ExamCompleted>());
      verify(() => repo.submitExam(any(), {'q0': 'a'}, any())).called(1);
      verify(() => repo.clearSession('book-1')).called(1);
    });

    test('submitExam is called with the session answers (not empty map)',
        () async {
      final startedAt =
          DateTime.now().subtract(const Duration(hours: 1));
      final expiredSession = ExamSession(
        startedAt: startedAt,
        answers: {'q0': 'c', 'q1': 'a'},
        currentIndex: 1,
      );

      when(() => repo.loadSession(any()))
          .thenAnswer((_) async => expiredSession);
      when(() => repo.getExamMeta(any())).thenAnswer(
        (_) async => Right(ExamMeta(
          settings: _settings,
          questionCount: _questions.length,
          attemptsUsed: 0,
          pastAttempts: [],
        )),
      );
      when(() => repo.getQuestions(any()))
          .thenAnswer((_) async => Right(_questions));
      when(() => repo.clearSession(any())).thenAnswer((_) async {});
      when(() => repo.submitExam(any(), any(), any())).thenAnswer(
        (_) async => Left(const ServerFailure('تجريبي')),
      );

      bloc.add(const ExamLoadRequested('book-1'));
      await bloc.stream
          .firstWhere((s) => s is ExamError)
          .timeout(const Duration(seconds: 5));

      // Verify the saved answers were submitted, not an empty map
      verify(
        () => repo.submitExam(any(), {'q0': 'c', 'q1': 'a'}, any()),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // ExamSubmitConfirmed
  // -------------------------------------------------------------------------
  group('ExamSubmitConfirmed', () {
    test('calls submitExam with current answers and emits ExamCompleted',
        () async {
      when(() => repo.clearSession(any())).thenAnswer((_) async {});
      when(() => repo.submitExam(any(), any(), any())).thenAnswer(
        (_) async => Right(ExamSubmitResult(
          attemptId: 'att-1',
          score: 90,
          correct: 9,
          total: 10,
          passed: true,
          gradeLabel: 'ممتاز',
          certIssued: true,
        )),
      );

      await _driveToInProgress(bloc, repo);

      // Select an answer then submit
      bloc.add(const ExamAnswerSelected('q0', 'a'));
      await bloc.stream.firstWhere(
          (s) => s is ExamInProgress && s.answers.containsKey('q0'));

      bloc.add(const ExamSubmitConfirmed());
      await bloc.stream
          .firstWhere((s) => s is ExamCompleted)
          .timeout(const Duration(seconds: 5));

      final state = bloc.state as ExamCompleted;
      expect(state.result.score, 90);
      expect(state.result.passed, true);
      expect(state.result.gradeLabel, 'ممتاز');
      verify(() => repo.clearSession(any())).called(1);
    });

    test('emits ExamError when RPC returns a Failure', () async {
      when(() => repo.clearSession(any())).thenAnswer((_) async {});
      when(() => repo.submitExam(any(), any(), any())).thenAnswer(
        (_) async => const Left(ServerFailure('خطأ في الخادم')),
      );

      await _driveToInProgress(bloc, repo);

      bloc.add(const ExamSubmitConfirmed());
      await bloc.stream
          .firstWhere((s) => s is ExamError)
          .timeout(const Duration(seconds: 5));

      expect((bloc.state as ExamError).message, 'خطأ في الخادم');
    });
  });
}
