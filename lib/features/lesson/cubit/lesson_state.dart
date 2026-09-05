// lib/features/lesson/cubit/lesson_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/lesson_entity.dart';
import '../../../models/lesson_progress_entity.dart';
import '../../../models/lesson_quiz_attempt_entity.dart';

abstract class LessonState extends Equatable {
  const LessonState();
  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

class LessonLoaded extends LessonState {
  final LessonEntity lesson;
  final LessonProgressEntity? progress;
  final bool hasQuizQuestions;
  final int quizQuestionCount;
  final int quizAttemptsUsed;
  final List<LessonQuizAttemptEntity> pastAttempts;
  final String? nextLessonId;
  final bool isSavingProgress;
  final bool videoWatched;

  const LessonLoaded({
    required this.lesson,
    this.progress,
    required this.hasQuizQuestions,
    this.quizQuestionCount = 0,
    this.quizAttemptsUsed = 0,
    this.pastAttempts = const [],
    this.nextLessonId,
    this.isSavingProgress = false,
    this.videoWatched = false,
  });

  LessonLoaded copyWith({
    LessonProgressEntity? progress,
    bool? hasQuizQuestions,
    int? quizQuestionCount,
    int? quizAttemptsUsed,
    List<LessonQuizAttemptEntity>? pastAttempts,
    String? nextLessonId,
    bool? isSavingProgress,
    bool? videoWatched,
  }) {
    return LessonLoaded(
      lesson: lesson,
      progress: progress ?? this.progress,
      hasQuizQuestions: hasQuizQuestions ?? this.hasQuizQuestions,
      quizQuestionCount: quizQuestionCount ?? this.quizQuestionCount,
      quizAttemptsUsed: quizAttemptsUsed ?? this.quizAttemptsUsed,
      pastAttempts: pastAttempts ?? this.pastAttempts,
      nextLessonId: nextLessonId ?? this.nextLessonId,
      isSavingProgress: isSavingProgress ?? this.isSavingProgress,
      videoWatched: videoWatched ?? this.videoWatched,
    );
  }

  bool get isCompleted => progress?.completed ?? false;
  int get lastPositionSeconds => progress?.lastPositionSeconds ?? 0;
  bool get quizAttempted => quizAttemptsUsed > 0;
  bool get quizExhausted => quizAttemptsUsed >= 2;

  @override
  List<Object?> get props => [
        lesson,
        progress,
        hasQuizQuestions,
        quizQuestionCount,
        quizAttemptsUsed,
        pastAttempts,
        nextLessonId,
        isSavingProgress,
        videoWatched,
      ];
}

class LessonError extends LessonState {
  final String message;
  const LessonError(this.message);
  @override
  List<Object?> get props => [message];
}
