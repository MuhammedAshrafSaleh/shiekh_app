// lib/features/admin/lessons/cubit/generate_questions_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../data/admin_lesson_repository.dart';
import 'generate_questions_state.dart';

/// Poll cadence while a job is queued/running — a safety net so a dropped
/// Realtime socket can never leave the screen spinning forever. Terminal states
/// stop the timer.
const _kPollInterval = Duration(seconds: 15);

/// Disambiguates this cubit's Realtime channel topics from the lesson-form
/// cubit's, which may watch the SAME lessons row at the same time (the generate
/// page is pushed over the form). See [AdminLessonRepository.subscribeToLesson].
const _kChannelKey = 'generate';

/// Drives the async, status-based AI flow. Both Edge Functions only ENQUEUE a
/// background job (HTTP 202) now; this cubit mirrors the two independent tracks
/// — transcription (on `public.lessons`) and question generation (on
/// `public.generation_jobs`) — from Realtime updates, with a poll fallback, and
/// re-derives the truth from the DB on open so the screen is fully resumable.
class GenerateQuestionsCubit extends Cubit<GenerateQuestionsState> {
  final AdminLessonRepository _repo;

  GenerateQuestionsCubit(this._repo) : super(GenerateQuestionsInitial());

  String? _lessonId;

  // Current truth, kept in fields so every emit rebuilds a consistent snapshot.
  String _transcriptStatus = 'none';
  String? _transcriptError;
  String? _transcript;
  String? _jobId;
  String? _jobStatus;
  String? _jobError;
  int? _resultCount;
  bool _isSubmitting = false;
  int _errorNonce = 0;

  RealtimeChannel? _lessonChannel;
  RealtimeChannel? _jobChannel;
  String? _subscribedJobId;
  Timer? _pollTimer;

  /// Page/tab open: read both tracks from the DB, emit the composite status, and
  /// wire up subscriptions/polling for whichever track is still active.
  Future<void> load(String lessonId) async {
    _lessonId = lessonId;
    emit(GenerateQuestionsLoading());
    final (lessonRes, jobRes) = await (
      _repo.getLesson(lessonId),
      _repo.getLatestGenerationJob(lessonId),
    ).wait;
    if (isClosed) return;

    // A failed lesson read is fatal (nothing to show). A failed job read is not
    // — it just means "no job yet".
    lessonRes.fold((f) => emit(GenerateQuestionsError(f.message)), (lesson) {
      _transcriptStatus = lesson.transcriptStatus;
      _transcriptError = lesson.transcriptError;
      _transcript = lesson.transcript;
      jobRes.fold((_) {}, (job) {
        if (job != null) {
          _jobId = job.id;
          _jobStatus = job.status;
          _jobError = job.errorMessage;
          _resultCount = job.resultCount;
        }
      });
      _emitReady();
      _syncSubscriptionsAndPolling();
    });
  }

  /// Enqueue transcription for a link source. 202 → the lesson row flips to
  /// 'queued'; we optimistically reflect that and start watching. A genuine
  /// 4xx/5xx stays on-screen as a transient error (the form remains usable).
  Future<void> enqueueTranscription({
    required String lessonId,
    required String sourceType, // 'youtube' | 'drive_audio'
    required String sourceUrl,
  }) async {
    _isSubmitting = true;
    _emitReady();
    final result = await _repo.transcribeLesson(
      lessonId: lessonId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
    );
    if (isClosed) return;
    _isSubmitting = false;
    result.fold(
      (f) => _emitReady(
        transientError: f.message,
        isOverload: f is AiOverloadFailure,
      ),
      (_) {
        _transcriptStatus = 'queued';
        _transcriptError = null;
        _emitReady();
        _syncSubscriptionsAndPolling();
      },
    );
  }

  /// Enqueue question generation from an available transcript. 202 returns the
  /// job_id of the NEW job; the backend supersedes any older one, so we switch
  /// our tracking to the newest id (pressing twice never tracks a stale job).
  Future<void> enqueueGeneration({
    required String lessonId,
    required String transcriptText,
    required int requestedCount,
    required Map<String, int> difficultyMix,
  }) async {
    _isSubmitting = true;
    _emitReady();
    final result = await _repo.generateQuestions(
      lessonId: lessonId,
      transcriptText: transcriptText,
      requestedCount: requestedCount,
      difficultyMix: difficultyMix,
    );
    if (isClosed) return;
    _isSubmitting = false;
    result.fold(
      (f) => _emitReady(
        transientError: f.message,
        isOverload: f is AiOverloadFailure,
      ),
      (ack) {
        _jobId = ack.jobId;
        _jobStatus = 'queued';
        _jobError = null;
        _resultCount = null;
        _emitReady();
        _syncSubscriptionsAndPolling();
      },
    );
  }

  void _onLessonUpdate(Map<String, dynamic> row) {
    if (isClosed) return;
    _transcriptStatus =
        (row['transcript_status'] as String?) ?? _transcriptStatus;
    _transcriptError = row['transcript_error'] as String?;
    _transcript = row['transcript'] as String?;
    _emitReady();
    _syncSubscriptionsAndPolling();
  }

  void _onJobUpdate(Map<String, dynamic> row) {
    if (isClosed) return;
    // Server-side filter already scopes this to our job id; ignore anything else
    // defensively in case a stale channel delivers late.
    if (row['id'] != _jobId) return;
    _jobStatus = row['status'] as String?;
    _jobError = row['error_message'] as String?;
    _resultCount = row['result_count'] as int?;
    _emitReady();
    _syncSubscriptionsAndPolling();
  }

  /// Poll fallback: re-read both tracks from the DB. Also adopts a newer job if
  /// one appeared (follow-the-newest-job), keeping the subscription in step.
  Future<void> _poll() async {
    final lessonId = _lessonId;
    if (lessonId == null) return;
    final (lessonRes, jobRes) = await (
      _repo.getLesson(lessonId),
      _repo.getLatestGenerationJob(lessonId),
    ).wait;
    if (isClosed) return;
    lessonRes.fold((_) {}, (lesson) {
      _transcriptStatus = lesson.transcriptStatus;
      _transcriptError = lesson.transcriptError;
      _transcript = lesson.transcript;
    });
    jobRes.fold((_) {}, (job) {
      if (job != null) {
        _jobId = job.id;
        _jobStatus = job.status;
        _jobError = job.errorMessage;
        _resultCount = job.resultCount;
      }
    });
    _emitReady();
    _syncSubscriptionsAndPolling();
  }

  /// Reconcile live resources with the current truth: subscribe to the lesson
  /// row while transcription is active, to the job row while generation is
  /// active (resubscribing if the tracked job id changed), and run the poll
  /// timer whenever either track is active. All are torn down once terminal.
  void _syncSubscriptionsAndPolling() {
    final lessonId = _lessonId;
    final transcriptActive =
        _transcriptStatus == 'queued' || _transcriptStatus == 'running';
    final jobActive = _jobStatus == 'queued' || _jobStatus == 'running';

    // Lesson (transcription) channel.
    if (transcriptActive && lessonId != null && _lessonChannel == null) {
      _lessonChannel = _repo.subscribeToLesson(
        lessonId,
        channelKey: _kChannelKey,
        onUpdate: _onLessonUpdate,
      );
    } else if (!transcriptActive && _lessonChannel != null) {
      _lessonChannel!.unsubscribe();
      _lessonChannel = null;
    }

    // Generation-job channel — resubscribe if the tracked job id changed.
    if (jobActive && _jobId != null && _subscribedJobId != _jobId) {
      _jobChannel?.unsubscribe();
      _subscribedJobId = _jobId;
      _jobChannel = _repo.subscribeToGenerationJob(
        _jobId!,
        channelKey: _kChannelKey,
        onUpdate: _onJobUpdate,
      );
    } else if (!jobActive && _jobChannel != null) {
      _jobChannel!.unsubscribe();
      _jobChannel = null;
      _subscribedJobId = null;
    }

    // Poll timer runs while anything is in flight.
    if ((transcriptActive || jobActive) && _pollTimer == null) {
      _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
    } else if (!transcriptActive && !jobActive) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _emitReady({String? transientError, bool isOverload = false}) {
    if (transientError != null) _errorNonce++;
    emit(
      GenerateQuestionsReady(
        transcriptStatus: _transcriptStatus,
        transcriptError: _transcriptError,
        transcript: _transcript,
        jobId: _jobId,
        jobStatus: _jobStatus,
        jobError: _jobError,
        resultCount: _resultCount,
        isSubmitting: _isSubmitting,
        transientError: transientError,
        transientIsOverload: isOverload,
        errorNonce: _errorNonce,
      ),
    );
  }

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    await _lessonChannel?.unsubscribe();
    await _jobChannel?.unsubscribe();
    return super.close();
  }
}
