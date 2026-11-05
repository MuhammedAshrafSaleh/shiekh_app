// lib/models/job_enqueue_entity.dart
import 'package:equatable/equatable.dart';

/// Acknowledgement returned by the `transcribe-lesson` and `generate-questions`
/// Edge Functions under the async-queue contract. Both now return HTTP 202
/// `{ job_id, status: 'queued' }` in ~1–2 s and never return the work product;
/// the real progress is tracked on `public.lessons` (transcription) or
/// `public.generation_jobs` (question generation) and surfaced via Realtime.
class JobEnqueueEntity extends Equatable {
  final String jobId;

  /// Enqueue status as reported by the function — expected to be 'queued'.
  final String status;

  const JobEnqueueEntity({required this.jobId, required this.status});

  factory JobEnqueueEntity.fromJson(Map<String, dynamic> json) {
    return JobEnqueueEntity(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
    );
  }

  @override
  List<Object?> get props => [jobId, status];
}
