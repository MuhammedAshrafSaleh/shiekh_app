// lib/models/practice_eligible_lesson_entity.dart
import 'package:equatable/equatable.dart';

/// A lesson the student may draw practice questions from: they have submitted
/// its official quiz and it still holds [questionCount] approved questions.
/// Returned by the `get_practice_eligible_lessons` RPC.
class PracticeEligibleLessonEntity extends Equatable {
  final String lessonId;
  final String lessonTitle;
  final String bookTitle;
  final int questionCount;

  const PracticeEligibleLessonEntity({
    required this.lessonId,
    required this.lessonTitle,
    required this.bookTitle,
    required this.questionCount,
  });

  factory PracticeEligibleLessonEntity.fromJson(Map<String, dynamic> json) {
    return PracticeEligibleLessonEntity(
      lessonId: json['lesson_id'] as String,
      lessonTitle: json['lesson_title'] as String,
      bookTitle: json['book_title'] as String,
      questionCount: (json['question_count'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [lessonId, lessonTitle, bookTitle, questionCount];
}
