// lib/features/admin/lessons/cubit/generate_questions_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_lesson_repository.dart';
import 'generate_questions_state.dart';

// Midpoints of the observed wall-clock ranges for each phase, used to pace the
// estimated progress animation. Progress is capped at 90% until the real
// response arrives, so the bar never falsely reaches 100% before completion.
const _kTranscribeDuration = Duration(seconds: 85); // range: 65–100 s
const _kGenerateDuration = Duration(seconds: 80); // range: 30–130 s

class GenerateQuestionsCubit extends Cubit<GenerateQuestionsState> {
  final AdminLessonRepository _repo;

  Timer? _progressTimer;
  DateTime? _phaseStart;

  GenerateQuestionsCubit(this._repo) : super(GenerateQuestionsInitial());

  void _startProgressTimer({required bool isTranscribing}) {
    _progressTimer?.cancel();
    _phaseStart = DateTime.now();
    final expected =
        isTranscribing ? _kTranscribeDuration : _kGenerateDuration;
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed =
          DateTime.now().difference(_phaseStart!).inMilliseconds / 1000.0;
      final p = (elapsed / expected.inSeconds).clamp(0.0, 0.9);
      if (state is GenerateQuestionsTranscribing) {
        emit(GenerateQuestionsTranscribing(progress: p));
      } else if (state is GenerateQuestionsGenerating) {
        emit(GenerateQuestionsGenerating(progress: p));
      } else {
        _progressTimer?.cancel();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _phaseStart = null;
  }

  /// Direct generation from an already-available transcript — used by the
  /// "paste text" source and by the "use saved transcript" shortcut.
  Future<void> generate({
    required String lessonId,
    required String transcriptText,
    required int requestedCount,
    required Map<String, int> difficultyMix,
    // When set, any generation failure re-emits it so the saved-transcript card
    // stays visible no matter how many times generation fails.
    String? savedTranscript,
  }) async {
    emit(const GenerateQuestionsGenerating());
    _startProgressTimer(isTranscribing: false);
    final result = await _repo.generateQuestions(
      lessonId: lessonId,
      transcriptText: transcriptText,
      requestedCount: requestedCount,
      difficultyMix: difficultyMix,
    );
    _stopProgressTimer();
    result.fold(
      (f) => emit(
        GenerateQuestionsError(f.message, savedTranscript: savedTranscript),
      ),
      (r) => emit(GenerateQuestionsSuccess(r.insertedCount)),
    );
  }

  /// Chained flow for the link-based sources: transcribe first, then feed the
  /// resulting transcript into generation. Two sequential Edge Function calls
  /// so each stays under Supabase's 150 s wall-clock limit.
  Future<void> transcribeAndGenerate({
    required String lessonId,
    required String sourceType, // 'youtube' | 'drive_audio'
    required String sourceUrl,
    required int requestedCount,
    required Map<String, int> difficultyMix,
  }) async {
    emit(const GenerateQuestionsTranscribing());
    _startProgressTimer(isTranscribing: true);
    final transcribed = await _repo.transcribeLesson(
      lessonId: lessonId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
    );
    _stopProgressTimer();
    await transcribed.fold(
      // Phase one failed → stop; do NOT attempt generation. Inputs are kept.
      (f) async => emit(GenerateQuestionsError(f.message)),
      (t) async {
        emit(const GenerateQuestionsGenerating());
        _startProgressTimer(isTranscribing: false);
        final generated = await _repo.generateQuestions(
          lessonId: lessonId,
          transcriptText: t.transcriptText,
          requestedCount: requestedCount,
          difficultyMix: difficultyMix,
        );
        _stopProgressTimer();
        generated.fold(
          // Phase two failed but the transcript is saved — carry it so the page
          // can offer a one-tap "generate only" retry (no re-transcribe).
          (f) => emit(
            GenerateQuestionsError(
              '${f.message}\nالتفريغ محفوظ — يمكنك إعادة التوليد دون إعادة التفريغ',
              savedTranscript: t.transcriptText,
            ),
          ),
          (r) => emit(GenerateQuestionsSuccess(r.insertedCount)),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _stopProgressTimer();
    return super.close();
  }
}
