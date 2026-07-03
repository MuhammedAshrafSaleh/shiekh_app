// lib/features/lesson/cubit/lesson_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/lesson_entity.dart';
import '../../../models/lesson_progress_entity.dart';

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
  final bool quizAttempted;
  final String? nextLessonId;
  final bool isSavingProgress;

  const LessonLoaded({
    required this.lesson,
    this.progress,
    required this.hasQuizQuestions,
    this.quizAttempted = false,
    this.nextLessonId,
    this.isSavingProgress = false,
  });

  LessonLoaded copyWith({
    LessonProgressEntity? progress,
    bool? hasQuizQuestions,
    bool? quizAttempted,
    String? nextLessonId,
    bool? isSavingProgress,
  }) {
    return LessonLoaded(
      lesson: lesson,
      progress: progress ?? this.progress,
      hasQuizQuestions: hasQuizQuestions ?? this.hasQuizQuestions,
      quizAttempted: quizAttempted ?? this.quizAttempted,
      nextLessonId: nextLessonId ?? this.nextLessonId,
      isSavingProgress: isSavingProgress ?? this.isSavingProgress,
    );
  }

  bool get isCompleted => progress?.completed ?? false;
  int get lastPositionSeconds => progress?.lastPositionSeconds ?? 0;

  @override
  List<Object?> get props => [
        lesson,
        progress,
        hasQuizQuestions,
        quizAttempted,
        nextLessonId,
        isSavingProgress,
      ];
}

class LessonError extends LessonState {
  final String message;
  const LessonError(this.message);
  @override
  List<Object?> get props => [message];
}
