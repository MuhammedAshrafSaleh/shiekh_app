// lib/features/admin/lessons/cubit/generate_questions_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_lesson_repository.dart';
import 'generate_questions_state.dart';

class GenerateQuestionsCubit extends Cubit<GenerateQuestionsState> {
  final AdminLessonRepository _repo;

  GenerateQuestionsCubit(this._repo) : super(GenerateQuestionsInitial());

  Future<void> generate({
    required String lessonId,
    required String transcriptText,
    required int requestedCount,
    required Map<String, int> difficultyMix,
  }) async {
    emit(GenerateQuestionsGenerating());
    final result = await _repo.generateQuestions(
      lessonId: lessonId,
      transcriptText: transcriptText,
      requestedCount: requestedCount,
      difficultyMix: difficultyMix,
    );
    result.fold(
      (f) => emit(GenerateQuestionsError(f.message)),
      (r) => emit(GenerateQuestionsSuccess(r.insertedCount)),
    );
  }
}
