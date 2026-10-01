// lib/models/bank_lesson_summary_entity.dart
import 'package:equatable/equatable.dart';

/// One row of the `bank_lesson_summaries` RPC — a lesson that has at least one
/// importable (approved, original) quiz question, with its count. Powers Step 1
/// of the question-bank import drill-down.
class BankLessonSummaryEntity extends Equatable {
  final String lessonId;
  final String title;
  final int orderIndex;
  final int approvedCount;

  const BankLessonSummaryEntity({
    required this.lessonId,
    required this.title,
    required this.orderIndex,
    required this.approvedCount,
  });

  factory BankLessonSummaryEntity.fromJson(Map<String, dynamic> json) {
    return BankLessonSummaryEntity(
      lessonId: json['lesson_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int,
      approvedCount: (json['approved_count'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [lessonId, title, orderIndex, approvedCount];
}
