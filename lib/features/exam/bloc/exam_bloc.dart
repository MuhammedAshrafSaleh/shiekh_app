// lib/features/exam/bloc/exam_bloc.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../data/exam_repository.dart';
import 'exam_event.dart';
import 'exam_state.dart';

class ExamBloc extends Bloc<ExamEvent, ExamState> {
  final ExamRepository _repo;
  final _log = Logger('ExamBloc');
  Timer? _timer;

  ExamBloc(this._repo) : super(ExamInitial()) {
    on<ExamLoadRequested>(_onLoad);
    on<ExamStartRequested>(_onStart);
    on<ExamAnswerSelected>(_onAnswer);
    on<ExamNavigateTo>(_onNavigate);
    on<ExamTick>(_onTick);
    on<ExamSubmitConfirmed>(_onSubmitConfirmed);
    on<ExamAutoSubmit>(_onAutoSubmit);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const ExamTick());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // CC-11: check for saved session first; resume or auto-submit if expired
  Future<void> _onLoad(
      ExamLoadRequested event, Emitter<ExamState> emit) async {
    emit(ExamLoading());

    final session = await _repo.loadSession(event.bookId);

    if (session != null) {
      // Load both meta and questions for resume/auto-submit
      final metaResult = await _repo.getExamMeta(event.bookId);
      final questionsResult = await _repo.getQuestions(event.bookId);

      if (metaResult.isLeft() || questionsResult.isLeft()) {
        await _repo.clearSession(event.bookId);
        // Fall through to fresh meta load
      } else {
        final meta = metaResult.getOrElse(() => throw StateError(''));
        final questions = questionsResult.getOrElse(() => []);

        final elapsed =
            DateTime.now().difference(session.startedAt).inSeconds;
        final timeLimitSeconds = meta.settings.timeLimitMinutes * 60;
        final secondsRemaining = timeLimitSeconds - elapsed;

        if (secondsRemaining > 0) {
          // Resume active session (CC-11)
          _log.info('Resuming exam for ${event.bookId}, ${secondsRemaining}s left');
          emit(ExamInProgress(
            bookId: event.bookId,
            settings: meta.settings,
            questions: questions,
            answers: session.answers,
            currentIndex: session.currentIndex.clamp(0, questions.length - 1),
            secondsRemaining: secondsRemaining,
            startedAt: session.startedAt,
          ));
          _startTimer();
          return;
        } else {
          // Time expired — auto-submit with saved answers (CC-11, CC-12)
          _log.info('Auto-submitting expired session for ${event.bookId}');
          await _repo.clearSession(event.bookId);
          final submitResult = await _repo.submitExam(
            event.bookId,
            session.answers,
            session.startedAt,
          );
          submitResult.fold(
            (f) => emit(ExamError(f.message)),
            (result) => emit(ExamCompleted(
              result: result,
              settings: meta.settings,
              bookId: event.bookId,
            )),
          );
          return;
        }
      }
    }

    // No session — load intro meta
    final metaResult = await _repo.getExamMeta(event.bookId);
    metaResult.fold(
      (f) => emit(ExamError(f.message)),
      (meta) => emit(ExamMetaLoaded(
        bookId: event.bookId,
        settings: meta.settings,
        questionCount: meta.questionCount,
        attemptsUsed: meta.attemptsUsed,
        pastAttempts: meta.pastAttempts,
      )),
    );
  }

  Future<void> _onStart(
      ExamStartRequested event, Emitter<ExamState> emit) async {
    final current = state;
    if (current is! ExamMetaLoaded || current.isLocked) return;

    emit(current.copyWith(isStarting: true));

    final questionsResult = await _repo.getQuestions(current.bookId);

    questionsResult.fold(
      (f) => emit(ExamError(f.message)),
      (questions) {
        if (questions.isEmpty) {
          emit(ExamError('لا توجد أسئلة في هذا الاختبار'));
          return;
        }
        final startedAt = DateTime.now();
        final secondsRemaining = current.settings.timeLimitMinutes * 60;

        emit(ExamInProgress(
          bookId: current.bookId,
          settings: current.settings,
          questions: questions,
          answers: const {},
          currentIndex: 0,
          secondsRemaining: secondsRemaining,
          startedAt: startedAt,
        ));
        _startTimer();
        _saveSession(current.bookId, {}, 0, startedAt);
      },
    );
  }

  void _onAnswer(ExamAnswerSelected event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    final newAnswers = Map<String, String>.from(current.answers)
      ..[event.questionId] = event.choice;
    emit(current.copyWith(answers: newAnswers));
    _saveSession(current.bookId, newAnswers, current.currentIndex,
        current.startedAt);
  }

  void _onNavigate(ExamNavigateTo event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;
    if (event.index < 0 || event.index >= current.questions.length) return;

    emit(current.copyWith(currentIndex: event.index));
    _saveSession(current.bookId, current.answers, event.index,
        current.startedAt);
  }

  void _onTick(ExamTick event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    final newSeconds = current.secondsRemaining - 1;
    if (newSeconds <= 0) {
      _stopTimer();
      emit(current.copyWith(secondsRemaining: 0));
      add(const ExamAutoSubmit()); // CC-12
    } else {
      emit(current.copyWith(secondsRemaining: newSeconds));
    }
  }

  Future<void> _onSubmitConfirmed(
      ExamSubmitConfirmed event, Emitter<ExamState> emit) async {
    final current = state;
    if (current is! ExamInProgress) return;

    _stopTimer();
    emit(current.copyWith(isSubmitting: true));
    await _submit(current, emit);
  }

  Future<void> _onAutoSubmit(
      ExamAutoSubmit event, Emitter<ExamState> emit) async {
    final current = state;
    if (current is! ExamInProgress) return;

    _stopTimer();
    emit(current.copyWith(isSubmitting: true));
    await _submit(current, emit);
  }

  Future<void> _submit(
      ExamInProgress current, Emitter<ExamState> emit) async {
    await _repo.clearSession(current.bookId);

    final result = await _repo.submitExam(
      current.bookId,
      current.answers,
      current.startedAt,
    );

    result.fold(
      (f) => emit(ExamError(f.message)),
      (submitResult) => emit(ExamCompleted(
        result: submitResult,
        settings: current.settings,
        bookId: current.bookId,
      )),
    );
  }

  void _saveSession(
    String bookId,
    Map<String, String> answers,
    int currentIndex,
    DateTime startedAt,
  ) {
    _repo.saveSession(
      bookId,
      ExamSession(
        startedAt: startedAt,
        answers: answers,
        currentIndex: currentIndex,
      ),
    );
  }
}
