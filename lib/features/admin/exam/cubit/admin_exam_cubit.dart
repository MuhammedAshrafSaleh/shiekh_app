// lib/features/admin/exam/cubit/admin_exam_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/admin_quiz_question_entity.dart';
import '../data/admin_exam_repository.dart';
import 'admin_exam_state.dart';

class AdminExamCubit extends Cubit<AdminExamState> {
  final AdminExamRepository _repo;
  String? _bookId;

  AdminExamCubit(this._repo) : super(AdminExamInitial());

  Future<void> load(String bookId) async {
    _bookId = bookId;
    emit(AdminExamLoading());
    final settingsResult = await _repo.getSettings(bookId);
    await settingsResult.fold((f) async => emit(AdminExamError(f.message)), (
      settings,
    ) async {
      // Questions and the bank count are independent — fetch them concurrently.
      final (qResult, bankCountResult) = await (
        _repo.getQuestions(bookId),
        _repo.getBankQuestionsCount(bookId),
      ).wait;
      final bankCount = bankCountResult.fold((_) => 0, (c) => c);
      qResult.fold(
        (f) => emit(AdminExamError(f.message)),
        (questions) => emit(
          AdminExamLoaded(
            settings: settings,
            questions: questions,
            bankCount: bankCount,
          ),
        ),
      );
    });
  }

  Future<void> saveSettings({
    required int timeLimitMinutes,
    required int passingPercentage,
    required int maxAttempts,
    required bool isPublished,
  }) async {
    if (_bookId == null) return;
    final current = state;
    emit(AdminExamSaving());
    final result = await _repo.upsertSettings(
      bookId: _bookId!,
      timeLimitMinutes: timeLimitMinutes,
      passingPercentage: passingPercentage,
      maxAttempts: maxAttempts,
      isPublished: isPublished,
    );
    result.fold((f) {
      emit(AdminExamError(f.message));
      if (current is AdminExamLoaded) {
        emit(current); // restore
      }
    }, (_) => load(_bookId!));
  }

  Future<void> addQuestion({
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    if (_bookId == null) return;
    final result = await _repo.createQuestion(
      bookId: _bookId!,
      questionText: questionText,
      choiceA: choiceA,
      choiceB: choiceB,
      choiceC: choiceC,
      choiceD: choiceD,
      correctChoice: correctChoice,
    );
    result.fold((f) => emit(AdminExamError(f.message)), (q) {
      final current = state;
      if (current is AdminExamLoaded) {
        emit(
          AdminExamLoaded(
            settings: current.settings,
            questions: [...current.questions, q],
            bankCount: current.bankCount,
          ),
        );
      }
    });
  }

  Future<void> updateQuestion({
    required String questionId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    final result = await _repo.updateQuestion(
      id: questionId,
      questionText: questionText,
      choiceA: choiceA,
      choiceB: choiceB,
      choiceC: choiceC,
      choiceD: choiceD,
      correctChoice: correctChoice,
    );
    result.fold((f) => emit(AdminExamError(f.message)), (updated) {
      final current = state;
      if (current is AdminExamLoaded) {
        final qs = current.questions
            .map((q) => q.id == updated.id ? updated : q)
            .toList();
        emit(
          AdminExamLoaded(
            settings: current.settings,
            questions: qs,
            bankCount: current.bankCount,
          ),
        );
      }
    });
  }

  Future<void> deleteQuestion(String questionId) async {
    final result = await _repo.deleteQuestion(questionId);
    result.fold((f) => emit(AdminExamError(f.message)), (_) {
      final current = state;
      if (current is AdminExamLoaded) {
        final qs = current.questions.where((q) => q.id != questionId).toList();
        emit(
          AdminExamLoaded(
            settings: current.settings,
            questions: qs,
            bankCount: current.bankCount,
          ),
        );
      }
    });
  }

  Future<void> importFromBank(List<AdminQuizQuestionEntity> selected) async {
    if (_bookId == null) return;
    final result = await _repo.importBankQuestions(
      bookId: _bookId!,
      questions: selected,
    );
    result.fold((f) => emit(AdminExamError(f.message)), (_) => load(_bookId!));
  }

  Future<List<AdminQuizQuestionEntity>> getBankQuestions() async {
    if (_bookId == null) return [];
    final result = await _repo.getBankQuestions(_bookId!);
    return result.fold((_) => [], (qs) => qs);
  }

  Future<void> reorderQuestions(List<String> questionIds) async {
    final current = state;
    if (current is! AdminExamLoaded) return;

    final updates = questionIds
        .asMap()
        .entries
        .map((e) => (e.value, e.key))
        .toList();

    final result = await _repo.reorderQuestions(updates);
    result.fold((f) => emit(AdminExamError(f.message)), (_) {
      final reorderedQuestions = questionIds
          .asMap()
          .entries
          .map((e) => current.questions.firstWhere((q) => q.id == e.value))
          .toList();
      emit(
        AdminExamLoaded(
          settings: current.settings,
          questions: reorderedQuestions,
          bankCount: current.bankCount,
        ),
      );
    });
  }
}
