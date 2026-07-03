// lib/features/lesson/cubit/lesson_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/lesson_progress_entity.dart';
import '../data/lesson_repository.dart';
import 'lesson_state.dart';

class LessonCubit extends Cubit<LessonState> {
  final LessonRepository _repo;

  LessonCubit(this._repo) : super(LessonInitial());

  Future<void> loadLesson(String lessonId, String bookId) async {
    emit(LessonLoading());

    final lessonResult = await _repo.getLesson(lessonId);
    if (lessonResult.isLeft()) {
      emit(LessonError(lessonResult.fold((f) => f.message, (_) => '')));
      return;
    }
    final lesson = lessonResult.getOrElse(() => throw StateError(''));

    final progressResult = await _repo.getLessonProgress(lessonId);
    final quizResult = await _repo.getQuizQuestions(lessonId);
    final nextResult = await _repo.getNextLesson(bookId, lesson.orderIndex);

    final progress = progressResult.getOrElse(() => null);
    final hasQuiz = quizResult.fold((_) => false, (q) => q.isNotEmpty);
    final nextLesson = nextResult.getOrElse(() => null);

    emit(LessonLoaded(
      lesson: lesson,
      progress: progress,
      hasQuizQuestions: hasQuiz,
      nextLessonId: nextLesson?.id,
    ));
  }

  // Called periodically from video tab (rule L)
  Future<void> saveVideoPosition(int positionSeconds) async {
    final current = state;
    if (current is! LessonLoaded) return;

    await _repo.saveProgress(
      lessonId: current.lesson.id,
      lastPositionSeconds: positionSeconds,
      completed: current.isCompleted,
    );
  }

  // Called when video reaches ~90% or user taps "الدرس التالي" (rule L)
  Future<void> markVideoWatched() async {
    final current = state;
    if (current is! LessonLoaded || current.isCompleted) return;

    final shouldComplete =
        !current.hasQuizQuestions || current.quizAttempted;

    if (shouldComplete) {
      await _completeLesson(current);
    }
  }

  // Called from quiz tab after grading (rule L)
  Future<void> markQuizAttempted() async {
    final current = state;
    if (current is! LessonLoaded) return;

    final updated = current.copyWith(quizAttempted: true);
    emit(updated);

    final hasVideoProgress = current.progress != null &&
        current.progress!.lastPositionSeconds > 0;
    final noVideo = !current.lesson.hasVideo;

    if (hasVideoProgress || noVideo) {
      await _completeLesson(updated);
    }
  }

  Future<void> _completeLesson(LessonLoaded current) async {
    emit(current.copyWith(isSavingProgress: true));

    final result = await _repo.saveProgress(
      lessonId: current.lesson.id,
      lastPositionSeconds: current.lastPositionSeconds,
      completed: true,
    );

    result.fold(
      (_) => emit(current.copyWith(isSavingProgress: false)),
      (_) {
        final existingProgress = current.progress;
        final updatedProgress = existingProgress != null
            ? _withCompleted(existingProgress)
            : LessonProgressEntity(
                id: '',
                userId: '',
                lessonId: current.lesson.id,
                completed: true,
                lastPositionSeconds: current.lastPositionSeconds,
              );

        emit(current.copyWith(
          isSavingProgress: false,
          progress: updatedProgress,
        ));
      },
    );
  }

  LessonProgressEntity _withCompleted(LessonProgressEntity p) {
    return LessonProgressEntity(
      id: p.id,
      userId: p.userId,
      lessonId: p.lessonId,
      completed: true,
      lastPositionSeconds: p.lastPositionSeconds,
      completedAt: p.completedAt ?? DateTime.now(),
    );
  }
}
