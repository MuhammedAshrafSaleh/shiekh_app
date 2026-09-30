// lib/core/widgets/bank_import_state.dart
import 'package:equatable/equatable.dart';

import '../../models/admin_quiz_question_entity.dart';
import '../../models/bank_lesson_summary_entity.dart';

enum BankLessonsStatus { loading, loaded, error }

enum BankQuestionsStatus { idle, loading, loaded, error }

/// Single cohesive state for the bank-import drill-down picker. A self-contained
/// UI-picker cubit (like the original), so one immutable state class + copyWith
/// is clearer than split subclasses.
class BankImportState extends Equatable {
  // Step 1 — lessons list.
  final BankLessonsStatus lessonsStatus;
  final List<BankLessonSummaryEntity> lessons;
  final String? lessonsError;

  // Step 2 — per-lesson questions (null currentLessonId ⇒ showing lessons list).
  final String? currentLessonId;
  final BankQuestionsStatus questionsStatus;
  final String? questionsError;
  final Map<String, List<AdminQuizQuestionEntity>> questionsCache;

  // Selection persists across lessons. id → full entity (needed for import).
  final Map<String, AdminQuizQuestionEntity> selected;

  const BankImportState({
    this.lessonsStatus = BankLessonsStatus.loading,
    this.lessons = const [],
    this.lessonsError,
    this.currentLessonId,
    this.questionsStatus = BankQuestionsStatus.idle,
    this.questionsError,
    this.questionsCache = const {},
    this.selected = const {},
  });

  /// Questions of the lesson currently being viewed (from cache).
  List<AdminQuizQuestionEntity> get currentQuestions => currentLessonId == null
      ? const []
      : (questionsCache[currentLessonId] ?? const []);

  int selectedCountForLesson(String lessonId) =>
      selected.values.where((q) => q.lessonId == lessonId).length;

  int get selectedCount => selected.length;

  List<AdminQuizQuestionEntity> get selectedList => selected.values.toList();

  BankImportState copyWith({
    BankLessonsStatus? lessonsStatus,
    List<BankLessonSummaryEntity>? lessons,
    String? lessonsError,
    bool clearLessonsError = false,
    String? currentLessonId,
    bool resetCurrentLesson = false,
    BankQuestionsStatus? questionsStatus,
    String? questionsError,
    bool clearQuestionsError = false,
    Map<String, List<AdminQuizQuestionEntity>>? questionsCache,
    Map<String, AdminQuizQuestionEntity>? selected,
  }) {
    return BankImportState(
      lessonsStatus: lessonsStatus ?? this.lessonsStatus,
      lessons: lessons ?? this.lessons,
      lessonsError: clearLessonsError ? null : (lessonsError ?? this.lessonsError),
      currentLessonId: resetCurrentLesson
          ? null
          : (currentLessonId ?? this.currentLessonId),
      questionsStatus: questionsStatus ?? this.questionsStatus,
      questionsError:
          clearQuestionsError ? null : (questionsError ?? this.questionsError),
      questionsCache: questionsCache ?? this.questionsCache,
      selected: selected ?? this.selected,
    );
  }

  @override
  List<Object?> get props => [
    lessonsStatus,
    lessons,
    lessonsError,
    currentLessonId,
    questionsStatus,
    questionsError,
    questionsCache,
    selected,
  ];
}
