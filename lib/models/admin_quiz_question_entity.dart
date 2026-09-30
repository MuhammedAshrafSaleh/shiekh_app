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

  /// AI-generation metadata (migration 0011). Manual questions default to
  /// source='manual', ai_review_status='approved' server-side.
  final String source;
  final String aiReviewStatus;
  final String? difficulty;

  /// Review aids shown for pending AI questions: a verbatim quote from the
  /// transcript and a short rationale. Null for manual questions.
  final String? explanation;
  final String? sourceQuote;

  /// Set when this row was itself copied from another lesson's question via the
  /// bank import (migration 0019). Non-null ⇒ this is an imported copy, so it is
  /// excluded from the bank. Lets the lesson form mark its already-added sources.
  final String? sourceQuestionId;

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
    this.source = 'manual',
    this.aiReviewStatus = 'approved',
    this.difficulty,
    this.explanation,
    this.sourceQuote,
    this.sourceQuestionId,
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
      source: json['source'] as String? ?? 'manual',
      aiReviewStatus: json['ai_review_status'] as String? ?? 'approved',
      difficulty: json['difficulty'] as String?,
      explanation: json['explanation'] as String?,
      sourceQuote: json['source_quote'] as String?,
      sourceQuestionId: json['source_question_id'] as String?,
    );
  }

  /// AI-generated question awaiting admin review — invisible to students.
  bool get isPendingReview => aiReviewStatus == 'pending';

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
    source,
    aiReviewStatus,
    difficulty,
    explanation,
    sourceQuote,
    sourceQuestionId,
  ];
}
