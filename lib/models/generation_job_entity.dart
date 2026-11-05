// lib/models/generation_job_entity.dart
import 'package:equatable/equatable.dart';

/// A row of `public.generation_jobs` — the server-side progress record for a
/// background AI job. Under the async-queue contract the client tracks a
/// question-generation job by the `job_id` returned from `generate-questions`
/// and watches this row (Realtime + poll) until it reaches a terminal status.
class GenerationJobEntity extends Equatable {
  final String id;
  final String lessonId;
  final String jobType; // 'transcribe' | 'generate_questions'
  final String status; // 'queued' | 'running' | 'done' | 'failed'
  final int attempts;
  final int? resultCount;
  final String? errorMessage;

  const GenerationJobEntity({
    required this.id,
    required this.lessonId,
    required this.jobType,
    required this.status,
    this.attempts = 0,
    this.resultCount,
    this.errorMessage,
  });

  /// True while the worker is still processing this job (not yet terminal).
  bool get isActive => status == 'queued' || status == 'running';

  factory GenerationJobEntity.fromJson(Map<String, dynamic> json) {
    return GenerationJobEntity(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      jobType: json['job_type'] as String,
      status: json['status'] as String,
      attempts: json['attempts'] as int? ?? 0,
      resultCount: json['result_count'] as int?,
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    lessonId,
    jobType,
    status,
    attempts,
    resultCount,
    errorMessage,
  ];
}
