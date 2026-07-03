// lib/models/lesson_progress_entity.dart
import 'package:equatable/equatable.dart';

class LessonProgressEntity extends Equatable {
  final String id;
  final String userId;
  final String lessonId;
  final bool completed;
  final int lastPositionSeconds;
  final DateTime? completedAt;

  const LessonProgressEntity({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.completed,
    required this.lastPositionSeconds,
    this.completedAt,
  });

  factory LessonProgressEntity.fromJson(Map<String, dynamic> json) {
    return LessonProgressEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      completed: json['completed'] as bool,
      lastPositionSeconds: json['last_position_seconds'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, lessonId, completed, lastPositionSeconds, completedAt];
}
