// lib/features/admin/lessons/cubit/admin_lesson_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_lesson_repository.dart';
import 'admin_lesson_state.dart';

class AdminLessonListCubit extends Cubit<AdminLessonListState> {
  final AdminLessonRepository _repo;
  String? _bookId;

  AdminLessonListCubit(this._repo) : super(AdminLessonListInitial());

  Future<void> load(String bookId) async {
    _bookId = bookId;
    emit(AdminLessonListLoading());
    final result = await _repo.getLessons(bookId);
    result.fold(
      (f) => emit(AdminLessonListError(f.message)),
      (list) => list.isEmpty
          ? emit(AdminLessonListEmpty())
          : emit(AdminLessonListLoaded(list)),
    );
  }

  Future<void> refresh() async {
    if (_bookId != null) await load(_bookId!);
  }

  Future<void> togglePublish(String lessonId, bool publish) async {
    final result = await _repo.togglePublish(lessonId, publish);
    result.fold(
      (f) => emit(AdminLessonListError(f.message)),
      (_) => refresh(),
    );
  }

  Future<bool> reorder(List<({String id, int orderIndex})> updates) async {
    final result = await _repo.reorderLessons(updates);
    return result.fold((_) => false, (_) => true);
  }

  Future<void> delete(String lessonId) async {
    final result = await _repo.deleteLesson(lessonId);
    result.fold(
      (f) => emit(AdminLessonListError(f.message)),
      (_) => refresh(),
    );
  }
}

class AdminLessonFormCubit extends Cubit<AdminLessonFormState> {
  final AdminLessonRepository _repo;

  AdminLessonFormCubit(this._repo) : super(AdminLessonFormInitial());

  Future<void> load({String? lessonId}) async {
    emit(AdminLessonFormLoading());
    if (lessonId == null) {
      emit(const AdminLessonFormLoaded(lesson: null, quizQuestions: []));
      return;
    }
    final lessonResult = await _repo.getLesson(lessonId);
    await lessonResult.fold(
      (f) async => emit(AdminLessonFormError(f.message)),
      (lesson) async {
        final qResult = await _repo.getQuizQuestions(lessonId);
        qResult.fold(
          (f) => emit(AdminLessonFormError(f.message)),
          (qs) => emit(AdminLessonFormLoaded(lesson: lesson, quizQuestions: qs)),
        );
      },
    );
  }

  Future<void> save({
    String? lessonId,
    required String bookId,
    required String title,
    String? description,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
    required bool audioOnly,
    required String status,
  }) async {
    emit(AdminLessonFormSaving());
    final result = lessonId == null
        ? await _repo.createLesson(
            bookId: bookId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
            pdfUrl: pdfUrl,
            audioOnly: audioOnly,
            status: status,
          )
        : await _repo.updateLesson(
            id: lessonId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
            pdfUrl: pdfUrl,
            audioOnly: audioOnly,
            status: status,
          );
    result.fold(
      (f) => emit(AdminLessonFormError(f.message)),
      (lesson) => emit(AdminLessonFormSaved(lesson)),
    );
  }

  Future<void> addQuizQuestion({
    required String lessonId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    final current = state;
    final result = await _repo.createQuizQuestion(
      lessonId: lessonId,
      questionText: questionText,
      choiceA: choiceA,
      choiceB: choiceB,
      choiceC: choiceC,
      choiceD: choiceD,
      correctChoice: correctChoice,
    );
    result.fold(
      (f) => emit(AdminLessonFormError(f.message)),
      (q) {
        if (current is AdminLessonFormLoaded) {
          emit(AdminLessonFormLoaded(
            lesson: current.lesson,
            quizQuestions: [...current.quizQuestions, q],
          ));
        }
      },
    );
  }

  Future<void> updateQuizQuestion({
    required String questionId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    final current = state;
    final result = await _repo.updateQuizQuestion(
      id: questionId,
      questionText: questionText,
      choiceA: choiceA,
      choiceB: choiceB,
      choiceC: choiceC,
      choiceD: choiceD,
      correctChoice: correctChoice,
    );
    result.fold(
      (f) => emit(AdminLessonFormError(f.message)),
      (updated) {
        if (current is AdminLessonFormLoaded) {
          final qs = current.quizQuestions
              .map((q) => q.id == updated.id ? updated : q)
              .toList();
          emit(AdminLessonFormLoaded(lesson: current.lesson, quizQuestions: qs));
        }
      },
    );
  }

  Future<void> deleteQuizQuestion(String questionId) async {
    final current = state;
    final result = await _repo.deleteQuizQuestion(questionId);
    result.fold(
      (f) => emit(AdminLessonFormError(f.message)),
      (_) {
        if (current is AdminLessonFormLoaded) {
          final qs = current.quizQuestions
              .where((q) => q.id != questionId)
              .toList();
          emit(AdminLessonFormLoaded(lesson: current.lesson, quizQuestions: qs));
        }
      },
    );
  }
}
