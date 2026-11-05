// lib/features/admin/lessons/cubit/generate_questions_state.dart
import 'package:equatable/equatable.dart';

abstract class GenerateQuestionsState extends Equatable {
  const GenerateQuestionsState();
  @override
  List<Object?> get props => [];
}

class GenerateQuestionsInitial extends GenerateQuestionsState {}

/// The one-time read on page open that re-derives the true current status from
/// the database (lessons.transcript_status + the newest generation_jobs row), so
/// reopening the page after an app restart always shows reality.
class GenerateQuestionsLoading extends GenerateQuestionsState {}

/// Composite, status-driven state: it mirrors the two independent async tracks
/// re-read on every Realtime update / poll tick. The UI maps these fields to all
/// the Arabic status strings. This is NOT a terminal success/error — the admin
/// can leave and return; the screen never blocks.
class GenerateQuestionsReady extends GenerateQuestionsState {
  /// lessons.transcript_status: 'none' | 'queued' | 'running' | 'ready' | 'failed'.
  final String transcriptStatus;

  /// lessons.transcript_error — user-facing Arabic, only when [isTranscriptFailed].
  final String? transcriptError;

  /// lessons.transcript — only populated when [isTranscriptReady].
  final String? transcript;

  /// The generation_jobs row id being tracked (the newest job), or null if none.
  final String? jobId;

  /// generation_jobs.status: null | 'queued' | 'running' | 'done' | 'failed'.
  final String? jobStatus;

  /// generation_jobs.error_message, only when [isJobFailed].
  final String? jobError;

  /// generation_jobs.result_count, populated when [isJobDone].
  final int? resultCount;

  /// True while an enqueue call (~1–2 s) is in flight — disables the button.
  final bool isSubmitting;

  /// One-shot enqueue failure (overload / key-missing / network), surfaced as a
  /// SnackBar while the form stays usable. Cleared on the next normal emit.
  final String? transientError;

  /// True when [transientError] is an AI-overload failure (midnight-retry hint).
  final bool transientIsOverload;

  /// Bumped whenever [transientError] is set so two identical messages still
  /// produce distinct states and the SnackBar listener fires every time.
  final int errorNonce;

  const GenerateQuestionsReady({
    required this.transcriptStatus,
    this.transcriptError,
    this.transcript,
    this.jobId,
    this.jobStatus,
    this.jobError,
    this.resultCount,
    this.isSubmitting = false,
    this.transientError,
    this.transientIsOverload = false,
    this.errorNonce = 0,
  });

  bool get isTranscriptActive =>
      transcriptStatus == 'queued' || transcriptStatus == 'running';
  bool get isTranscriptReady => transcriptStatus == 'ready';
  bool get isTranscriptFailed => transcriptStatus == 'failed';

  /// True when a usable transcript is available (ready + non-empty).
  bool get hasTranscript =>
      isTranscriptReady && (transcript?.trim().isNotEmpty ?? false);

  bool get isJobActive => jobStatus == 'queued' || jobStatus == 'running';
  bool get isJobDone => jobStatus == 'done';
  bool get isJobFailed => jobStatus == 'failed';

  @override
  List<Object?> get props => [
    transcriptStatus,
    transcriptError,
    transcript,
    jobId,
    jobStatus,
    jobError,
    resultCount,
    isSubmitting,
    transientError,
    transientIsOverload,
    errorNonce,
  ];
}

/// Fatal failure of the page-open DB read (no data to show). Enqueue failures do
/// NOT land here — they stay on [GenerateQuestionsReady] as a transient error.
class GenerateQuestionsError extends GenerateQuestionsState {
  final String message;
  const GenerateQuestionsError(this.message);
  @override
  List<Object?> get props => [message];
}
