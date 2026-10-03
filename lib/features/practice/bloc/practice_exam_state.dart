// lib/features/practice/bloc/practice_exam_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/quiz_question_entity.dart';
import '../data/practice_repository.dart';

abstract class PracticeExamState extends Equatable {
  const PracticeExamState();

  @override
  List<Object?> get props => [];
}

class PracticeExamLoading extends PracticeExamState {}

class PracticeExamError extends PracticeExamState {
  final String message;
  const PracticeExamError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Active practice session. Nothing is persisted — leaving discards it.
class PracticeExamInProgress extends PracticeExamState {
  final List<QuizQuestionEntity> questions;
  final Map<String, String> answers; // questionId → choice
  final int currentIndex;
  final bool timerEnabled;
  final int secondsRemaining;
  final DateTime startedAt;
  final bool isSubmitting;

  /// Set when a submission failed — the exam stays in progress (answers kept)
  /// and the UI offers «إعادة المحاولة». Null while submitting or normally.
  final String? submitError;

  const PracticeExamInProgress({
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.timerEnabled,
    required this.secondsRemaining,
    required this.startedAt,
    this.isSubmitting = false,
    this.submitError,
  });

  QuizQuestionEntity get currentQuestion => questions[currentIndex];
  int get answeredCount => answers.length;
  int get unansweredCount => questions.length - answeredCount;

  /// Time has run out — no further answering is allowed, but a failed
  /// auto-submit can still be retried.
  bool get isTimeUp => timerEnabled && secondsRemaining <= 0;

  PracticeExamInProgress copyWith({
    Map<String, String>? answers,
    int? currentIndex,
    int? secondsRemaining,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return PracticeExamInProgress(
      questions: questions,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      timerEnabled: timerEnabled,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      startedAt: startedAt,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  @override
  List<Object?> get props => [
    questions,
    answers,
    currentIndex,
    timerEnabled,
    secondsRemaining,
    startedAt,
    isSubmitting,
    submitError,
  ];
}

/// Submitted and graded — the UI navigates to the result screen.
class PracticeExamCompleted extends PracticeExamState {
  final PracticeSubmitResult result;
  const PracticeExamCompleted(this.result);

  @override
  List<Object?> get props => [result];
}
