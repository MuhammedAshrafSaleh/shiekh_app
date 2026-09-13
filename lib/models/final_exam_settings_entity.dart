// lib/models/final_exam_settings_entity.dart
import 'package:equatable/equatable.dart';

class FinalExamSettingsEntity extends Equatable {
  final String bookId;
  final int timeLimitMinutes;
  final int passingPercentage;
  final int maxAttempts;
  final bool isPublished;

  const FinalExamSettingsEntity({
    required this.bookId,
    required this.timeLimitMinutes,
    required this.passingPercentage,
    required this.maxAttempts,
    required this.isPublished,
  });

  factory FinalExamSettingsEntity.fromJson(Map<String, dynamic> json) {
    return FinalExamSettingsEntity(
      bookId: json['book_id'] as String,
      timeLimitMinutes: json['time_limit_minutes'] as int,
      passingPercentage: json['passing_percentage'] as int,
      maxAttempts: json['max_attempts'] as int,
      isPublished: json['is_published'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    bookId,
    timeLimitMinutes,
    passingPercentage,
    maxAttempts,
    isPublished,
  ];
}
