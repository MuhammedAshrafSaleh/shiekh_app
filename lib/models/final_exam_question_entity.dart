// lib/models/final_exam_question_entity.dart
import 'package:equatable/equatable.dart';

class FinalExamQuestionEntity extends Equatable {
  final String id;
  final String bookId;
  final int orderIndex;
  final String questionText;
  final String choiceA;
  final String choiceB;
  final String choiceC;
  final String choiceD;

  const FinalExamQuestionEntity({
    required this.id,
    required this.bookId,
    required this.orderIndex,
    required this.questionText,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.choiceD,
  });

  factory FinalExamQuestionEntity.fromJson(Map<String, dynamic> json) {
    return FinalExamQuestionEntity(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      orderIndex: json['order_index'] as int,
      questionText: json['question_text'] as String,
      choiceA: json['choice_a'] as String,
      choiceB: json['choice_b'] as String,
      choiceC: json['choice_c'] as String,
      choiceD: json['choice_d'] as String,
    );
  }

  String choiceLabel(String key) {
    return switch (key) {
      'a' => choiceA,
      'b' => choiceB,
      'c' => choiceC,
      'd' => choiceD,
      _ => '',
    };
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        orderIndex,
        questionText,
        choiceA,
        choiceB,
        choiceC,
        choiceD,
      ];
}
