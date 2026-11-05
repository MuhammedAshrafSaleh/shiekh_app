// lib/models/final_exam_attempt_entity.dart
import 'package:equatable/equatable.dart';

class FinalExamAttemptEntity extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final int attemptNumber;
  final int scorePercentage;
  final bool passed;
  final DateTime startedAt;
  final DateTime? submittedAt;

  const FinalExamAttemptEntity({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.attemptNumber,
    required this.scorePercentage,
    required this.passed,
    required this.startedAt,
    this.submittedAt,
  });

  factory FinalExamAttemptEntity.fromJson(Map<String, dynamic> json) {
    return FinalExamAttemptEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      attemptNumber: json['attempt_number'] as int,
      scorePercentage: json['score_percentage'] as int,
      passed: json['passed'] as bool,
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    bookId,
    attemptNumber,
    scorePercentage,
    passed,
    startedAt,
    submittedAt,
  ];
}
