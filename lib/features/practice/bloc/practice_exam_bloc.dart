// lib/features/practice/bloc/practice_exam_bloc.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../../../models/quiz_question_entity.dart';
import '../data/practice_repository.dart';
import '../logic/practice_exam_builder.dart';
import '../logic/practice_exam_config.dart';
import 'practice_exam_event.dart';
import 'practice_exam_state.dart';

/// Runs one practice exam: uses the questions prefetched by the loading screen
/// (or builds them itself), tracks answers, optionally counts down, and submits
/// for server-side grading. A failed submission keeps the exam in progress with
/// all answers preserved so the student can retry. No persistence — leaving the
/// screen discards everything.
class PracticeExamBloc extends Bloc<PracticeExamEvent, PracticeExamState> {
  final PracticeRepository _repo;
  final PracticeExamConfig _config;
  final List<QuizQuestionEntity>? _prebuilt;
  final Random _random;
  final _log = Logger('PracticeExamBloc');
  Timer? _timer;

  PracticeExamBloc(
    this._repo,
    this._config, {
    List<QuizQuestionEntity>? prebuiltQuestions,
    Random? random,
  }) : _prebuilt = prebuiltQuestions,
       _random = random ?? Random(),
       super(PracticeExamLoading()) {
    on<PracticeExamStarted>(_onStarted);
    on<PracticeExamAnswerSelected>(_onAnswer);
    on<PracticeExamNavigateTo>(_onNavigate);
    on<PracticeExamTick>(_onTick);
    on<PracticeExamSubmitted>(_onSubmitted);
    on<PracticeExamAutoSubmitted>(_onAutoSubmitted);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const PracticeExamTick());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onStarted(
    PracticeExamStarted event,
    Emitter<PracticeExamState> emit,
  ) async {
    // Prefetched by the loading screen — open instantly.
    final prebuilt = _prebuilt;
    if (prebuilt != null && prebuilt.isNotEmpty) {
      _beginExam(prebuilt, emit);
      return;
    }

    // Skip-before-ready or retry: build here.
    emit(PracticeExamLoading());
    final result = await buildPracticeExam(_repo, _config, _random);
    result.fold(
      (f) => emit(PracticeExamError(f.message)),
      (questions) => _beginExam(questions, emit),
    );
  }

  void _beginExam(
    List<QuizQuestionEntity> questions,
    Emitter<PracticeExamState> emit,
  ) {
    emit(
      PracticeExamInProgress(
        questions: questions,
        answers: const {},
        currentIndex: 0,
        timerEnabled: _config.timerEnabled,
        secondsRemaining: _config.timeLimitMinutes * 60,
        startedAt: DateTime.now(),
      ),
    );
    if (_config.timerEnabled) _startTimer();
  }

  void _onAnswer(
    PracticeExamAnswerSelected event,
    Emitter<PracticeExamState> emit,
  ) {
    final s = state;
    // No answering while submitting or after time is up.
    if (s is! PracticeExamInProgress || s.isSubmitting || s.isTimeUp) return;
    final answers = Map<String, String>.from(s.answers)
      ..[event.questionId] = event.choice;
    emit(s.copyWith(answers: answers));
  }

  void _onNavigate(
    PracticeExamNavigateTo event,
    Emitter<PracticeExamState> emit,
  ) {
    final s = state;
    if (s is! PracticeExamInProgress || s.isSubmitting) return;
    if (event.index < 0 || event.index >= s.questions.length) return;
    emit(s.copyWith(currentIndex: event.index));
  }

  void _onTick(PracticeExamTick event, Emitter<PracticeExamState> emit) {
    final s = state;
    if (s is! PracticeExamInProgress || s.isSubmitting) return;

    final remaining = _secondsRemaining(s.startedAt);
    if (remaining <= 0) {
      _stopTimer();
      emit(s.copyWith(secondsRemaining: 0));
      add(const PracticeExamAutoSubmitted());
    } else {
      emit(s.copyWith(secondsRemaining: remaining));
    }
  }

  Future<void> _onSubmitted(
    PracticeExamSubmitted event,
    Emitter<PracticeExamState> emit,
  ) async {
    await _submit(emit);
  }

  Future<void> _onAutoSubmitted(
    PracticeExamAutoSubmitted event,
    Emitter<PracticeExamState> emit,
  ) async {
    await _submit(emit);
  }

  Future<void> _submit(Emitter<PracticeExamState> emit) async {
    final s = state;
    // Double-submit guard: ignore while a submission is already in flight.
    if (s is! PracticeExamInProgress || s.isSubmitting) return;

    _stopTimer();
    emit(s.copyWith(isSubmitting: true, clearSubmitError: true));

    final durationSeconds = DateTime.now().difference(s.startedAt).inSeconds;
    final result = await _repo.submitAttempt(
      questionOrder: [for (final q in s.questions) q.id],
      answers: s.answers,
      durationSeconds: durationSeconds < 0 ? 0 : durationSeconds,
      timeLimitMinutes: _config.effectiveTimeLimit,
    );

    result.fold((f) {
      _log.warning('submit failed: ${f.message}');
      // Keep the exam in progress with answers preserved; offer retry.
      final cur = state;
      if (cur is PracticeExamInProgress) {
        emit(cur.copyWith(isSubmitting: false, submitError: f.message));
      }
    }, (r) => emit(PracticeExamCompleted(r)));
  }

  /// Wall-clock remaining time so background pauses are correctly deducted.
  int _secondsRemaining(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return _config.timeLimitMinutes * 60 - elapsed;
  }
}
