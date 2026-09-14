// lib/features/admin/lessons/cubit/admin_lesson_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/lesson_pdf_entity.dart';

abstract class AdminLessonListState extends Equatable {
  const AdminLessonListState();
  @override
  List<Object?> get props => [];
}

class AdminLessonListInitial extends AdminLessonListState {}

class AdminLessonListLoading extends AdminLessonListState {}

class AdminLessonListLoaded extends AdminLessonListState {
  final List<LessonEntity> lessons;
  const AdminLessonListLoaded(this.lessons);
  @override
  List<Object?> get props => [lessons];
}

class AdminLessonListEmpty extends AdminLessonListState {}

class AdminLessonListError extends AdminLessonListState {
  final String message;
  const AdminLessonListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Form state (single lesson create/edit) ────────────────────────────────

abstract class AdminLessonFormState extends Equatable {
  const AdminLessonFormState();
  @override
  List<Object?> get props => [];
}

class AdminLessonFormInitial extends AdminLessonFormState {}

class AdminLessonFormLoading extends AdminLessonFormState {}

class AdminLessonFormLoaded extends AdminLessonFormState {
  final LessonEntity? lesson;
  final List<AdminQuizQuestionEntity> quizQuestions;

  /// The lesson's PDFs (migration 0012), sorted by order_index. Maintained by
  /// the PDF CRUD methods so mutations don't require refetching the whole lesson.
  final List<LessonPdfEntity> pdfs;

  /// Number of quiz questions available in the other lessons of this book
  /// (source for "استيراد من البنك" on the quiz tab).
  final int bankCount;

  const AdminLessonFormLoaded({
    this.lesson,
    required this.quizQuestions,
    this.pdfs = const [],
    this.bankCount = 0,
  });
  @override
  List<Object?> get props => [lesson, quizQuestions, pdfs, bankCount];
}

class AdminLessonFormSaving extends AdminLessonFormState {}

class AdminLessonFormSaved extends AdminLessonFormState {
  final LessonEntity lesson;
  const AdminLessonFormSaved(this.lesson);
  @override
  List<Object?> get props => [lesson];
}

class AdminLessonFormError extends AdminLessonFormState {
  final String message;
  const AdminLessonFormError(this.message);
  @override
  List<Object?> get props => [message];
}
