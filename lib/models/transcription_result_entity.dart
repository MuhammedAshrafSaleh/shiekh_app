// lib/models/transcription_result_entity.dart
import 'package:equatable/equatable.dart';

/// Success payload returned by the `transcribe-lesson` Edge Function. Carries
/// the full transcript text so the client can chain it straight into the
/// `generate-questions` call without re-fetching the lesson.
class TranscriptionResultEntity extends Equatable {
  final String jobId;
  final String transcriptText;

  const TranscriptionResultEntity({
    required this.jobId,
    required this.transcriptText,
  });

  factory TranscriptionResultEntity.fromJson(Map<String, dynamic> json) {
    return TranscriptionResultEntity(
      jobId: json['job_id'] as String? ?? '',
      transcriptText: json['transcript_text'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [jobId, transcriptText];
}
