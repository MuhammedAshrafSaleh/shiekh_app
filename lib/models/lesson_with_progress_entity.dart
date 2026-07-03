// lib/models/lesson_with_progress_entity.dart
import 'package:equatable/equatable.dart';

import 'lesson_entity.dart';
import 'lesson_progress_entity.dart';

class LessonWithProgressEntity extends Equatable {
  final LessonEntity lesson;
  final LessonProgressEntity? progress;
  final bool hasQuizQuestions;

  const LessonWithProgressEntity({
    required this.lesson,
    this.progress,
    this.hasQuizQuestions = false,
  });

  bool get isCompleted => progress?.completed ?? false;
  int get lastPositionSeconds => progress?.lastPositionSeconds ?? 0;

  @override
  List<Object?> get props => [lesson, progress, hasQuizQuestions];
}
