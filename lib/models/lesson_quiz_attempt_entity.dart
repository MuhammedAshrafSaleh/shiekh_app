// lib/models/lesson_quiz_attempt_entity.dart
import 'package:equatable/equatable.dart';

class LessonQuizAttemptEntity extends Equatable {
  final String id;
  final String userId;
  final String lessonId;
  final int attemptNumber;
  final int scorePercentage;
  final bool passed;
  final DateTime submittedAt;

  const LessonQuizAttemptEntity({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.attemptNumber,
    required this.scorePercentage,
    required this.passed,
    required this.submittedAt,
  });

  factory LessonQuizAttemptEntity.fromJson(Map<String, dynamic> json) {
    return LessonQuizAttemptEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      attemptNumber: json['attempt_number'] as int,
      scorePercentage: json['score_percentage'] as int,
      passed: json['passed'] as bool,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    lessonId,
    attemptNumber,
    scorePercentage,
    passed,
    submittedAt,
  ];
}
