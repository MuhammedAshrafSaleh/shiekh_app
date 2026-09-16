// lib/features/admin/lessons/cubit/generate_questions_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_lesson_repository.dart';
import 'generate_questions_state.dart';

class GenerateQuestionsCubit extends Cubit<GenerateQuestionsState> {
  final AdminLessonRepository _repo;

  GenerateQuestionsCubit(this._repo) : super(GenerateQuestionsInitial());

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
    emit(GenerateQuestionsGenerating());
    final result = await _repo.generateQuestions(
      lessonId: lessonId,
      transcriptText: transcriptText,
      requestedCount: requestedCount,
      difficultyMix: difficultyMix,
    );
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
    emit(GenerateQuestionsTranscribing());
    final transcribed = await _repo.transcribeLesson(
      lessonId: lessonId,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
    );
    await transcribed.fold(
      // Phase one failed → stop; do NOT attempt generation. Inputs are kept.
      (f) async => emit(GenerateQuestionsError(f.message)),
      (t) async {
        emit(GenerateQuestionsGenerating());
        final generated = await _repo.generateQuestions(
          lessonId: lessonId,
          transcriptText: t.transcriptText,
          requestedCount: requestedCount,
          difficultyMix: difficultyMix,
        );
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
}
