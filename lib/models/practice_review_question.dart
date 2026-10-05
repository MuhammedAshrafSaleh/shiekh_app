// lib/models/practice_review_question.dart
import 'package:equatable/equatable.dart';

/// One reviewed question of a practice attempt. When the underlying question
/// was deleted after submission the row is a tombstone ([isDeleted] = true)
/// and the content fields are null — the UI shows «هذا السؤال تم حذفه».
class PracticeReviewQuestion extends Equatable {
  final String questionId;
  final bool isDeleted;
  final String? questionText;
  final String? choiceA;
  final String? choiceB;
  final String? choiceC;
  final String? choiceD;
  final String? correctChoice;
  final String? userAnswer;
  final bool isCorrect;
  final String? lessonTitle;

  const PracticeReviewQuestion({
    required this.questionId,
    required this.isDeleted,
    required this.questionText,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.choiceD,
    required this.correctChoice,
    required this.userAnswer,
    required this.isCorrect,
    required this.lessonTitle,
  });

  factory PracticeReviewQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeReviewQuestion(
      questionId: json['question_id'] as String,
      isDeleted: json['is_deleted'] as bool? ?? false,
      questionText: json['question_text'] as String?,
      choiceA: json['choice_a'] as String?,
      choiceB: json['choice_b'] as String?,
      choiceC: json['choice_c'] as String?,
      choiceD: json['choice_d'] as String?,
      correctChoice: json['correct_choice'] as String?,
      userAnswer: json['user_answer'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
      lessonTitle: json['lesson_title'] as String?,
    );
  }

  String? choiceText(String key) => switch (key) {
    'a' => choiceA,
    'b' => choiceB,
    'c' => choiceC,
    'd' => choiceD,
    _ => null,
  };

  @override
  List<Object?> get props => [
    questionId,
    isDeleted,
    questionText,
    choiceA,
    choiceB,
    choiceC,
    choiceD,
    correctChoice,
    userAnswer,
    isCorrect,
    lessonTitle,
  ];
}
