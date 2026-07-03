// lib/models/admin_quiz_question_entity.dart
import 'package:equatable/equatable.dart';

/// Admin-side quiz question — includes correct_choice (never sent to students).
class AdminQuizQuestionEntity extends Equatable {
  final String id;
  final String lessonId;
  final int orderIndex;
  final String questionText;
  final String choiceA;
  final String choiceB;
  final String choiceC;
  final String choiceD;
  final String correctChoice;

  const AdminQuizQuestionEntity({
    required this.id,
    required this.lessonId,
    required this.orderIndex,
    required this.questionText,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.choiceD,
    required this.correctChoice,
  });

  factory AdminQuizQuestionEntity.fromJson(Map<String, dynamic> json) {
    return AdminQuizQuestionEntity(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      orderIndex: json['order_index'] as int,
      questionText: json['question_text'] as String,
      choiceA: json['choice_a'] as String,
      choiceB: json['choice_b'] as String,
      choiceC: json['choice_c'] as String,
      choiceD: json['choice_d'] as String,
      correctChoice: json['correct_choice'] as String,
    );
  }

  String choiceLabel(String key) => switch (key) {
        'a' => choiceA,
        'b' => choiceB,
        'c' => choiceC,
        'd' => choiceD,
        _ => '',
      };

  @override
  List<Object?> get props => [
        id,
        lessonId,
        orderIndex,
        questionText,
        choiceA,
        choiceB,
        choiceC,
        choiceD,
        correctChoice,
      ];
}
