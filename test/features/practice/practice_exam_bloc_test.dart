// test/features/practice/practice_exam_bloc_test.dart
import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/practice/bloc/practice_exam_bloc.dart';
import 'package:sheikhy_app/features/practice/bloc/practice_exam_event.dart';
import 'package:sheikhy_app/features/practice/bloc/practice_exam_state.dart';
import 'package:sheikhy_app/features/practice/data/practice_repository.dart';
import 'package:sheikhy_app/features/practice/logic/practice_exam_config.dart';
import 'package:sheikhy_app/models/quiz_question_entity.dart';

class _MockPracticeRepository extends Mock implements PracticeRepository {}

QuizQuestionEntity _q(String id, String lesson) => QuizQuestionEntity(
  id: id,
  lessonId: lesson,
  orderIndex: 0,
  questionText: 'نص $id',
  choiceA: 'أ',
  choiceB: 'ب',
  choiceC: 'ج',
  choiceD: 'د',
);

// 25 questions across two lessons.
final _pool = [
  for (var i = 0; i < 13; i++) _q('L1Q$i', 'L1'),
  for (var i = 0; i < 12; i++) _q('L2Q$i', 'L2'),
];

const _config = PracticeExamConfig(
  lessonIds: ['L1', 'L2'],
  questionCount: 20,
  timerEnabled: false,
  timeLimitMinutes: 30,
);

PracticeExamBloc _bloc(_MockPracticeRepository repo) =>
    PracticeExamBloc(repo, _config, random: Random(1));

void main() {
  late _MockPracticeRepository repo;

  setUp(() {
    repo = _MockPracticeRepository();
    when(
      () => repo.getQuestionPool(any()),
    ).thenAnswer((_) async => Right(_pool));
  });

  test('Started builds an in-progress exam of exactly 20 questions', () async {
    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());

    final state = await bloc.stream.firstWhere(
      (s) => s is PracticeExamInProgress || s is PracticeExamError,
    );

    expect(state, isA<PracticeExamInProgress>());
    final inProgress = state as PracticeExamInProgress;
    expect(inProgress.questions, hasLength(20));
    expect(inProgress.questions.map((q) => q.id).toSet(), hasLength(20));
    expect(inProgress.timerEnabled, isFalse);
    await bloc.close();
  });

  test('pool fetch failure emits Error', () async {
    when(
      () => repo.getQuestionPool(any()),
    ).thenAnswer((_) async => Left(ServerFailure('boom')));
    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());

    final state = await bloc.stream.firstWhere((s) => s is PracticeExamError);
    expect(state, isA<PracticeExamError>());
    await bloc.close();
  });

  test('answer selection and navigation update the state', () async {
    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    final started =
        await bloc.stream.firstWhere((s) => s is PracticeExamInProgress)
            as PracticeExamInProgress;

    final firstId = started.questions.first.id;
    bloc.add(PracticeExamAnswerSelected(firstId, 'b'));
    final answered =
        await bloc.stream.firstWhere(
              (s) => s is PracticeExamInProgress && s.answers.isNotEmpty,
            )
            as PracticeExamInProgress;
    expect(answered.answers[firstId], 'b');

    bloc.add(const PracticeExamNavigateTo(3));
    final navigated =
        await bloc.stream.firstWhere(
              (s) => s is PracticeExamInProgress && s.currentIndex == 3,
            )
            as PracticeExamInProgress;
    expect(navigated.currentIndex, 3);
    await bloc.close();
  });

  test('submit success emits Completed with the result', () async {
    const result = PracticeSubmitResult(
      attemptId: 'att-1',
      score: 80,
      correct: 16,
      total: 20,
      breakdown: [],
      review: [],
    );
    when(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).thenAnswer((_) async => const Right(result));

    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    await bloc.stream.firstWhere((s) => s is PracticeExamInProgress);

    bloc.add(const PracticeExamSubmitted());
    final state = await bloc.stream.firstWhere(
      (s) => s is PracticeExamCompleted,
    );
    expect((state as PracticeExamCompleted).result.score, 80);
    await bloc.close();
  });

  test('manual submit failure keeps answers; retry succeeds', () async {
    const result = PracticeSubmitResult(
      attemptId: 'a',
      score: 70,
      correct: 14,
      total: 20,
      breakdown: [],
      review: [],
    );
    var calls = 0;
    when(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).thenAnswer((_) async {
      calls++;
      return calls == 1 ? Left(ServerFailure('offline')) : const Right(result);
    });

    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    final started =
        await bloc.stream.firstWhere((s) => s is PracticeExamInProgress)
            as PracticeExamInProgress;
    final firstId = started.questions.first.id;

    bloc.add(PracticeExamAnswerSelected(firstId, 'a'));
    await bloc.stream.firstWhere(
      (s) => s is PracticeExamInProgress && s.answers.isNotEmpty,
    );

    // First submit fails → stays in progress, answers kept, error shown.
    bloc.add(const PracticeExamSubmitted());
    final failed =
        await bloc.stream.firstWhere(
              (s) => s is PracticeExamInProgress && s.submitError != null,
            )
            as PracticeExamInProgress;
    expect(failed.answers[firstId], 'a');
    expect(failed.isSubmitting, isFalse);

    // Retry succeeds.
    bloc.add(const PracticeExamSubmitted());
    final done = await bloc.stream.firstWhere(
      (s) => s is PracticeExamCompleted,
    );
    expect((done as PracticeExamCompleted).result.score, 70);
    await bloc.close();
  });

  test('auto-submit failure keeps answers; retry succeeds', () async {
    const result = PracticeSubmitResult(
      attemptId: 'a',
      score: 55,
      correct: 11,
      total: 20,
      breakdown: [],
      review: [],
    );
    var calls = 0;
    when(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).thenAnswer((_) async {
      calls++;
      return calls == 1 ? Left(ServerFailure('timeout')) : const Right(result);
    });

    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    final started =
        await bloc.stream.firstWhere((s) => s is PracticeExamInProgress)
            as PracticeExamInProgress;
    final firstId = started.questions.first.id;
    bloc.add(PracticeExamAnswerSelected(firstId, 'c'));
    await bloc.stream.firstWhere(
      (s) => s is PracticeExamInProgress && s.answers.isNotEmpty,
    );

    // Simulate a timeout auto-submit that fails.
    bloc.add(const PracticeExamAutoSubmitted());
    final failed =
        await bloc.stream.firstWhere(
              (s) => s is PracticeExamInProgress && s.submitError != null,
            )
            as PracticeExamInProgress;
    expect(failed.answers[firstId], 'c');

    // Manual retry succeeds.
    bloc.add(const PracticeExamSubmitted());
    final done = await bloc.stream.firstWhere(
      (s) => s is PracticeExamCompleted,
    );
    expect(done, isA<PracticeExamCompleted>());
    await bloc.close();
  });

  test('double submission is ignored while one is in flight', () async {
    final completer = Completer<Either<Failure, PracticeSubmitResult>>();
    when(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).thenAnswer((_) => completer.future);

    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    await bloc.stream.firstWhere((s) => s is PracticeExamInProgress);

    // Two rapid submits — only the first should reach the repository.
    bloc.add(const PracticeExamSubmitted());
    await bloc.stream.firstWhere(
      (s) => s is PracticeExamInProgress && s.isSubmitting,
    );
    bloc.add(const PracticeExamSubmitted());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    completer.complete(
      const Right(
        PracticeSubmitResult(
          attemptId: 'a',
          score: 60,
          correct: 12,
          total: 20,
          breakdown: [],
          review: [],
        ),
      ),
    );
    await bloc.stream.firstWhere((s) => s is PracticeExamCompleted);

    verify(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).called(1);
    await bloc.close();
  });

  test('submit sends timeLimitMinutes = null when the timer is off', () async {
    const result = PracticeSubmitResult(
      attemptId: 'a',
      score: 50,
      correct: 10,
      total: 20,
      breakdown: [],
      review: [],
    );
    when(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: any(named: 'timeLimitMinutes'),
      ),
    ).thenAnswer((_) async => const Right(result));

    final bloc = _bloc(repo);
    bloc.add(const PracticeExamStarted());
    await bloc.stream.firstWhere((s) => s is PracticeExamInProgress);
    bloc.add(const PracticeExamSubmitted());
    await bloc.stream.firstWhere((s) => s is PracticeExamCompleted);

    final captured = verify(
      () => repo.submitAttempt(
        questionOrder: any(named: 'questionOrder'),
        answers: any(named: 'answers'),
        durationSeconds: any(named: 'durationSeconds'),
        timeLimitMinutes: captureAny(named: 'timeLimitMinutes'),
      ),
    ).captured;
    expect(captured.single, isNull);
    await bloc.close();
  });
}
