// lib/core/widgets/bank_import_cubit.dart
//
// Drives the full-screen bank-import drill-down (BankImportPage): loads the
// book's lessons (Step 1), lazily loads + caches each lesson's questions on
// drill-in (Step 2), and holds the selection (kept across lessons so import has
// the full question data). Kept as a Cubit per the app's convention.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/admin/shared/data/question_bank_repository.dart';
import '../../models/admin_quiz_question_entity.dart';
import 'bank_import_state.dart';

class BankImportCubit extends Cubit<BankImportState> {
  final QuestionBankRepository _repo;
  final String _bookId;

  BankImportCubit(this._repo, this._bookId) : super(const BankImportState());

  /// Step 1: load the book's lessons that have importable questions.
  Future<void> loadLessons() async {
    emit(state.copyWith(
      lessonsStatus: BankLessonsStatus.loading,
      clearLessonsError: true,
    ));
    final result = await _repo.getBankLessonSummaries(_bookId);
    result.fold(
      (f) => emit(
        state.copyWith(
          lessonsStatus: BankLessonsStatus.error,
          lessonsError: f.message,
        ),
      ),
      (lessons) => emit(
        state.copyWith(
          lessonsStatus: BankLessonsStatus.loaded,
          lessons: lessons,
        ),
      ),
    );
  }

  /// Step 2: drill into a lesson. Serves from cache when already fetched.
  Future<void> openLesson(String lessonId) async {
    if (state.questionsCache.containsKey(lessonId)) {
      emit(
        state.copyWith(
          currentLessonId: lessonId,
          questionsStatus: BankQuestionsStatus.loaded,
          clearQuestionsError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        currentLessonId: lessonId,
        questionsStatus: BankQuestionsStatus.loading,
        clearQuestionsError: true,
      ),
    );
    final result = await _repo.getLessonBankQuestions(lessonId);
    result.fold(
      (f) => emit(
        state.copyWith(
          questionsStatus: BankQuestionsStatus.error,
          questionsError: f.message,
        ),
      ),
      (qs) {
        final cache = Map<String, List<AdminQuizQuestionEntity>>.from(
          state.questionsCache,
        )..[lessonId] = qs;
        // Only flip to "loaded" if the user hasn't navigated away meanwhile.
        final stillCurrent = state.currentLessonId == lessonId;
        emit(
          state.copyWith(
            questionsCache: cache,
            questionsStatus: stillCurrent
                ? BankQuestionsStatus.loaded
                : state.questionsStatus,
          ),
        );
      },
    );
  }

  /// Back to the lessons list (selection is preserved).
  void backToLessons() {
    emit(
      state.copyWith(
        resetCurrentLesson: true,
        questionsStatus: BankQuestionsStatus.idle,
        clearQuestionsError: true,
      ),
    );
  }

  /// Add/remove a single question from the selection.
  void toggle(AdminQuizQuestionEntity question) {
    final next = Map<String, AdminQuizQuestionEntity>.from(state.selected);
    if (next.remove(question.id) == null) next[question.id] = question;
    emit(state.copyWith(selected: next));
  }

  /// Select-all toggle over the given (already search-filtered, non-added)
  /// questions: if all are selected → deselect them; otherwise select them all.
  void selectAllFiltered(List<AdminQuizQuestionEntity> filtered) {
    if (filtered.isEmpty) return;
    final next = Map<String, AdminQuizQuestionEntity>.from(state.selected);
    final allSelected = filtered.every((q) => next.containsKey(q.id));
    for (final q in filtered) {
      if (allSelected) {
        next.remove(q.id);
      } else {
        next[q.id] = q;
      }
    }
    emit(state.copyWith(selected: next));
  }
}
