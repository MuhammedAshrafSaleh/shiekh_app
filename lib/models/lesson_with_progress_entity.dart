// lib/models/lesson_with_progress_entity.dart
import 'package:equatable/equatable.dart';

import 'lesson_entity.dart';
import 'lesson_progress_entity.dart';

class LessonWithProgressEntity extends Equatable {
  final LessonEntity lesson;
  final LessonProgressEntity? progress;
  final bool hasQuizQuestions;

  // Media-presence flags for the list. Sourced from the URL-free `lessons_public`
  // view, which never exposes the URLs themselves — so these can't be derived
  // from `lesson` (its URL fields are null in list context).
  final bool hasVideo;
  final bool hasAudio;
  final bool hasPdf;

  const LessonWithProgressEntity({
    required this.lesson,
    this.progress,
    this.hasQuizQuestions = false,
    this.hasVideo = false,
    this.hasAudio = false,
    this.hasPdf = false,
  });

  bool get isCompleted => progress?.completed ?? false;
  int get lastPositionSeconds => progress?.lastPositionSeconds ?? 0;

  @override
  List<Object?> get props => [
    lesson,
    progress,
    hasQuizQuestions,
    hasVideo,
    hasAudio,
    hasPdf,
  ];
}
