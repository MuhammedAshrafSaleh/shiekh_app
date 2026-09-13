// lib/models/generated_questions_result_entity.dart
import 'package:equatable/equatable.dart';

/// Success payload returned by the `generate-questions` Edge Function.
/// The generated questions themselves are re-fetched from the lesson's
/// question list; here we only need the job id and how many rows were inserted.
class GeneratedQuestionsResultEntity extends Equatable {
  final String jobId;
  final int insertedCount;

  const GeneratedQuestionsResultEntity({
    required this.jobId,
    required this.insertedCount,
  });

  factory GeneratedQuestionsResultEntity.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestionsResultEntity(
      jobId: json['job_id'] as String? ?? '',
      insertedCount: json['inserted_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [jobId, insertedCount];
}
