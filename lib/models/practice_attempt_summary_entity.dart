// lib/models/practice_attempt_summary_entity.dart
import 'package:equatable/equatable.dart';

import 'practice_lecture_breakdown.dart';

/// Lightweight summary of a submitted practice attempt for the history list
/// ("امتحاناتي السابقة"). Fetched with summary columns only — the heavy
/// `answers`/`question_order` payloads are loaded on tap via the review RPC.
class PracticeAttemptSummaryEntity extends Equatable {
  final String id;
  final int scorePercentage;
  final int correctCount;
  final int totalCount;
  final List<String> lessonIds;
  final List<PracticeLectureBreakdown> breakdown;
  final int durationSeconds;
  final int? timeLimitMinutes;
  final DateTime createdAt;

  const PracticeAttemptSummaryEntity({
    required this.id,
    required this.scorePercentage,
    required this.correctCount,
    required this.totalCount,
    required this.lessonIds,
    required this.breakdown,
    required this.durationSeconds,
    required this.timeLimitMinutes,
    required this.createdAt,
  });

  /// Number of lectures this attempt drew from.
  int get lectureCount => lessonIds.length;

  factory PracticeAttemptSummaryEntity.fromJson(Map<String, dynamic> json) {
    return PracticeAttemptSummaryEntity(
      id: json['id'] as String,
      scorePercentage: (json['score_percentage'] as num).toInt(),
      correctCount: (json['correct_count'] as num).toInt(),
      totalCount: (json['total_count'] as num).toInt(),
      lessonIds:
          (json['lesson_ids'] as List?)?.map((e) => e as String).toList() ??
          const [],
      breakdown:
          (json['breakdown'] as List?)
              ?.map(
                (e) => PracticeLectureBreakdown.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    scorePercentage,
    correctCount,
    totalCount,
    lessonIds,
    breakdown,
    durationSeconds,
    timeLimitMinutes,
    createdAt,
  ];
}
