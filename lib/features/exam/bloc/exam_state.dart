// lib/features/exam/bloc/exam_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/final_exam_attempt_entity.dart';
import '../../../models/final_exam_question_entity.dart';
import '../../../models/final_exam_settings_entity.dart';
import '../data/exam_repository.dart';

abstract class ExamState extends Equatable {
  const ExamState();

  @override
  List<Object?> get props => [];
}

class ExamInitial extends ExamState {}

class ExamLoading extends ExamState {}

// Intro screen state — metadata loaded, no active session
class ExamMetaLoaded extends ExamState {
  final String bookId;
  final FinalExamSettingsEntity settings;
  final int questionCount;
  final int attemptsUsed;
  final List<FinalExamAttemptEntity> pastAttempts;

  // True when questions are being fetched after tapping "بدء"
  final bool isStarting;

  const ExamMetaLoaded({
    required this.bookId,
    required this.settings,
    required this.questionCount,
    required this.attemptsUsed,
    required this.pastAttempts,
    this.isStarting = false,
  });

  bool get attemptsExhausted => attemptsUsed >= settings.maxAttempts;
  bool get isLocked =>
      !settings.isPublished || questionCount == 0 || attemptsExhausted;

  ExamMetaLoaded copyWith({bool? isStarting}) {
    return ExamMetaLoaded(
      bookId: bookId,
      settings: settings,
      questionCount: questionCount,
      attemptsUsed: attemptsUsed,
      pastAttempts: pastAttempts,
      isStarting: isStarting ?? this.isStarting,
    );
  }

  @override
  List<Object?> get props => [
    bookId,
    settings,
    questionCount,
    attemptsUsed,
    pastAttempts,
    isStarting,
  ];
}

// Active exam session
class ExamInProgress extends ExamState {
  final String bookId;
  final FinalExamSettingsEntity settings;
  final List<FinalExamQuestionEntity> questions;
  final Map<String, String> answers; // questionId → choice
  final int currentIndex;
  final int secondsRemaining;
  final DateTime startedAt;
  final bool isSubmitting;

  const ExamInProgress({
    required this.bookId,
    required this.settings,
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.secondsRemaining,
    required this.startedAt,
    this.isSubmitting = false,
  });

  FinalExamQuestionEntity get currentQuestion => questions[currentIndex];

  int get answeredCount => answers.length;

  int get unansweredCount => questions.length - answeredCount;

  // Navigator status: null = unanswered, 'answered' = answered, 'current' = current
  String? questionStatus(int index) {
    if (index == currentIndex) return 'current';
    final q = questions[index];
    if (answers.containsKey(q.id)) return 'answered';
    return null;
  }

  ExamInProgress copyWith({
    Map<String, String>? answers,
    int? currentIndex,
    int? secondsRemaining,
    bool? isSubmitting,
  }) {
    return ExamInProgress(
      bookId: bookId,
      settings: settings,
      questions: questions,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      startedAt: startedAt,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
    bookId,
    settings,
    questions,
    answers,
    currentIndex,
    secondsRemaining,
    startedAt,
    isSubmitting,
  ];
}

// RPC returned — navigate to result screen
class ExamCompleted extends ExamState {
  final ExamSubmitResult result;
  final FinalExamSettingsEntity settings;
  final String bookId;

  const ExamCompleted({
    required this.result,
    required this.settings,
    required this.bookId,
  });

  @override
  List<Object?> get props => [result, settings, bookId];
}

class ExamError extends ExamState {
  final String message;
  const ExamError(this.message);

  @override
  List<Object?> get props => [message];
}
