// lib/features/qa/cubit/my_questions_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/qa_repository.dart';
import 'my_questions_state.dart';

class MyQuestionsCubit extends Cubit<MyQuestionsState> {
  final QaRepository _repo;

  MyQuestionsCubit(this._repo) : super(MyQuestionsInitial());

  Future<void> loadMyQuestions() async {
    emit(MyQuestionsLoading());
    final result = await _repo.getMyQuestions();
    result.fold(
      (failure) => emit(MyQuestionsError(failure.message)),
      (questions) =>
          emit(questions.isEmpty ? MyQuestionsEmpty() : MyQuestionsLoaded(questions)),
    );
  }
}
