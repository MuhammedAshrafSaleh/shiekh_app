// lib/models/practice_lecture_breakdown.dart
import 'package:equatable/equatable.dart';

/// Per-lecture score slice of a practice attempt (frozen at submit time).
class PracticeLectureBreakdown extends Equatable {
  final String lessonId;
  final String lessonTitle;
  final int correct;
  final int total;

  const PracticeLectureBreakdown({
    required this.lessonId,
    required this.lessonTitle,
    required this.correct,
    required this.total,
  });

  factory PracticeLectureBreakdown.fromJson(Map<String, dynamic> json) {
    return PracticeLectureBreakdown(
      lessonId: json['lesson_id'] as String,
      lessonTitle: json['lesson_title'] as String,
      correct: (json['correct'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [lessonId, lessonTitle, correct, total];
}
