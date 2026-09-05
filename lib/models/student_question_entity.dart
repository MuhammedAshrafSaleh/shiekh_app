// lib/models/student_question_entity.dart
import 'package:equatable/equatable.dart';

class StudentQuestionEntity extends Equatable {
  final String id;
  final String bookId;
  final String? lessonId;
  final String questionText;
  final String? answerText;
  final String status;
  final DateTime? answeredAt;
  final DateTime createdAt;

  const StudentQuestionEntity({
    required this.id,
    required this.bookId,
    this.lessonId,
    required this.questionText,
    this.answerText,
    required this.status,
    this.answeredAt,
    required this.createdAt,
  });

  bool get isAnswered => status == 'answered';

  factory StudentQuestionEntity.fromJson(Map<String, dynamic> json) {
    return StudentQuestionEntity(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      lessonId: json['lesson_id'] as String?,
      questionText: json['question_text'] as String,
      answerText: json['answer_text'] as String?,
      status: json['status'] as String,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        lessonId,
        questionText,
        answerText,
        status,
        answeredAt,
        createdAt,
      ];
}
