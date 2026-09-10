// lib/models/lesson_progress_entity.dart
import 'package:equatable/equatable.dart';

class LessonProgressEntity extends Equatable {
  final String id;
  final String userId;
  final String lessonId;
  final bool completed;

  /// Kept for backward compatibility; no longer written. Resume now uses the
  /// per-medium fields below (see 0009_split_media_position.sql).
  final int lastPositionSeconds;
  final int videoPositionSeconds;
  final int audioPositionSeconds;
  final DateTime? completedAt;

  const LessonProgressEntity({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.completed,
    this.lastPositionSeconds = 0,
    this.videoPositionSeconds = 0,
    this.audioPositionSeconds = 0,
    this.completedAt,
  });

  factory LessonProgressEntity.fromJson(Map<String, dynamic> json) {
    return LessonProgressEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      completed: json['completed'] as bool,
      lastPositionSeconds: json['last_position_seconds'] as int? ?? 0,
      videoPositionSeconds: json['video_position_seconds'] as int? ?? 0,
      audioPositionSeconds: json['audio_position_seconds'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  LessonProgressEntity copyWith({
    String? id,
    String? userId,
    String? lessonId,
    bool? completed,
    int? lastPositionSeconds,
    int? videoPositionSeconds,
    int? audioPositionSeconds,
    DateTime? completedAt,
  }) {
    return LessonProgressEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      completed: completed ?? this.completed,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      videoPositionSeconds: videoPositionSeconds ?? this.videoPositionSeconds,
      audioPositionSeconds: audioPositionSeconds ?? this.audioPositionSeconds,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    lessonId,
    completed,
    lastPositionSeconds,
    videoPositionSeconds,
    audioPositionSeconds,
    completedAt,
  ];
}
