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
    on<ExamBackgroundLeave>(_onBackgroundLeave);
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
  Future<void> _onLoad(ExamLoadRequested event, Emitter<ExamState> emit) async {
    emit(ExamLoading());

    // Enrollment gate (guest or registered-not-enrolled). A guest is never
    // enrolled, so one check covers both. Runs before any exam data loads.
    final enrolledResult = await _repo.isEnrolled(event.bookId);
    final bool? enrolled = enrolledResult.fold((f) {
      emit(ExamError(f.message));
      return null;
    }, (value) => value);
    if (enrolled == null) return; // load failed — error already emitted
    if (!enrolled) {
      emit(ExamGated(bookId: event.bookId));
      return;
    }

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

        final secondsRemaining = _secondsRemaining(
          session.startedAt,
          meta.settings.timeLimitMinutes,
        );

        if (secondsRemaining > 0) {
          // Resume active session (CC-11)
          _log.info(
            'Resuming exam for ${event.bookId}, ${secondsRemaining}s left',
          );
          emit(
            ExamInProgress(
              bookId: event.bookId,
              settings: meta.settings,
              questions: questions,
              answers: session.answers,
              currentIndex: session.currentIndex.clamp(0, questions.length - 1),
              secondsRemaining: secondsRemaining,
              startedAt: session.startedAt,
            ),
          );
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
            (result) => emit(
              ExamCompleted(
                result: result,
                settings: meta.settings,
                bookId: event.bookId,
              ),
            ),
          );
          return;
        }
      }
    }

    // No session — load intro meta
    final metaResult = await _repo.getExamMeta(event.bookId);
    metaResult.fold(
      (f) => emit(ExamError(f.message)),
      (meta) => emit(
        ExamMetaLoaded(
          bookId: event.bookId,
          settings: meta.settings,
          questionCount: meta.questionCount,
          attemptsUsed: meta.attemptsUsed,
          pastAttempts: meta.pastAttempts,
        ),
      ),
    );
  }

  Future<void> _onStart(
    ExamStartRequested event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamMetaLoaded || current.isLocked) return;

    emit(current.copyWith(isStarting: true));

    final questionsResult = await _repo.getQuestions(current.bookId);

    questionsResult.fold((f) => emit(ExamError(f.message)), (questions) {
      if (questions.isEmpty) {
        emit(ExamError('لا توجد أسئلة في هذا الاختبار'));
        return;
      }
      final startedAt = DateTime.now();
      final secondsRemaining = current.settings.timeLimitMinutes * 60;

      emit(
        ExamInProgress(
          bookId: current.bookId,
          settings: current.settings,
          questions: questions,
          answers: const {},
          currentIndex: 0,
          secondsRemaining: secondsRemaining,
          startedAt: startedAt,
        ),
      );
      _startTimer();
      _saveSession(current.bookId, {}, 0, startedAt);
    });
  }

  void _onAnswer(ExamAnswerSelected event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    final newAnswers = Map<String, String>.from(current.answers)
      ..[event.questionId] = event.choice;
    emit(current.copyWith(answers: newAnswers));
    _saveSession(
      current.bookId,
      newAnswers,
      current.currentIndex,
      current.startedAt,
    );
  }

  void _onNavigate(ExamNavigateTo event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;
    if (event.index < 0 || event.index >= current.questions.length) return;

    emit(current.copyWith(currentIndex: event.index));
    _saveSession(
      current.bookId,
      current.answers,
      event.index,
      current.startedAt,
    );
  }

  void _onTick(ExamTick event, Emitter<ExamState> emit) {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    final remaining = _secondsRemaining(
      current.startedAt,
      current.settings.timeLimitMinutes,
    );
    if (remaining <= 0) {
      _stopTimer();
      emit(current.copyWith(secondsRemaining: 0));
      add(const ExamAutoSubmit()); // CC-12
    } else {
      emit(current.copyWith(secondsRemaining: remaining));
    }
  }

  Future<void> _onSubmitConfirmed(
    ExamSubmitConfirmed event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    _stopTimer();
    emit(current.copyWith(isSubmitting: true));
    await _submit(current, emit);
  }

  Future<void> _onAutoSubmit(
    ExamAutoSubmit event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    _stopTimer();
    emit(current.copyWith(isSubmitting: true));
    await _submit(current, emit);
  }

  Future<void> _submit(ExamInProgress current, Emitter<ExamState> emit) async {
    await _repo.clearSession(current.bookId);

    final result = await _repo.submitExam(
      current.bookId,
      current.answers,
      current.startedAt,
    );

    result.fold(
      (f) => emit(ExamError(f.message)),
      (submitResult) => emit(
        ExamCompleted(
          result: submitResult,
          settings: current.settings,
          bookId: current.bookId,
        ),
      ),
    );
  }

  /// Seconds remaining based on wall-clock elapsed time, so background pauses
  /// are correctly deducted rather than relying on tick count.
  int _secondsRemaining(DateTime startedAt, int timeLimitMinutes) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return timeLimitMinutes * 60 - elapsed;
  }

  Future<void> _onBackgroundLeave(
    ExamBackgroundLeave event,
    Emitter<ExamState> emit,
  ) async {
    final current = state;
    if (current is! ExamInProgress || current.isSubmitting) return;

    // Recompute time first — if the student stayed away until the clock ran
    // out, treat it as a normal time-up submit with no warning or leave count.
    final remaining = _secondsRemaining(
      current.startedAt,
      current.settings.timeLimitMinutes,
    );
    if (remaining <= 0) {
      _stopTimer();
      emit(current.copyWith(secondsRemaining: 0));
      add(const ExamAutoSubmit());
      return;
    }

    final newCount = current.backgroundLeaveCount + 1;
    // Always emit the new count so the UI listener fires, then auto-submit on 2.
    emit(
      current.copyWith(
        backgroundLeaveCount: newCount,
        secondsRemaining: remaining,
      ),
    );
    if (newCount >= ExamInProgress.backgroundLeaveLimit) {
      add(const ExamAutoSubmit());
    }
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
