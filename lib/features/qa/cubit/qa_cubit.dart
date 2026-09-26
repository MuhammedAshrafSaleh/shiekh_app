// lib/features/qa/cubit/qa_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/qa_repository.dart';
import 'qa_state.dart';

class QaCubit extends Cubit<QaState> {
  final QaRepository _repo;

  QaCubit(this._repo) : super(QaInitial());

  Future<void> loadQuestions(String bookId) async {
    emit(QaLoading());
    final result = await _repo.getBookQuestions(bookId);
    result.fold(
      (failure) => emit(QaError(failure.message)),
      (questions) =>
          emit(questions.isEmpty ? QaEmpty() : QaLoaded(questions)),
    );
  }
}

class AskQuestionCubit extends Cubit<AskQuestionState> {
  final QaRepository _repo;

  AskQuestionCubit(this._repo) : super(AskQuestionIdle());

  Future<void> submit({
    required String bookId,
    String? lessonId,
    required String questionText,
  }) async {
    emit(AskQuestionSubmitting());
    final result = await _repo.askQuestion(
      bookId: bookId,
      lessonId: lessonId,
      questionText: questionText,
    );
    result.fold(
      (failure) => emit(AskQuestionError(failure.message)),
      (_) => emit(AskQuestionSubmitted()),
    );
  }
}
