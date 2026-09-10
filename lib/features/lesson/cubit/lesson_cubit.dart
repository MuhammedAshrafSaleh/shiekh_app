// lib/features/lesson/cubit/lesson_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/lesson_progress_entity.dart';
import '../../../models/lesson_quiz_attempt_entity.dart';
import '../data/lesson_repository.dart';
import '../data/video_stream_repository.dart';
import 'lesson_state.dart';

// Fallback when getQuizMeta fails — treated as no quiz
class _EmptyQuizMeta implements LessonQuizMeta {
  const _EmptyQuizMeta();
  @override
  bool get hasQuiz => false;
  @override
  int get questionCount => 0;
  @override
  int get attemptsUsed => 0;
  @override
  List<LessonQuizAttemptEntity> get pastAttempts => const [];
}

class LessonCubit extends Cubit<LessonState> {
  final LessonRepository _repo;
  final VideoStreamRepository _videoStreamRepo;

  LessonCubit(this._repo, this._videoStreamRepo) : super(LessonInitial());

  Future<void> loadLesson(String lessonId, String bookId) async {
    emit(LessonLoading());

    final lessonResult = await _repo.getLesson(lessonId);
    if (lessonResult.isLeft()) {
      emit(LessonError(lessonResult.fold((f) => f.message, (_) => '')));
      return;
    }
    final lesson = lessonResult.getOrElse(() => throw StateError(''));

    final progressResult = await _repo.getLessonProgress(lessonId);
    final quizMetaResult = await _repo.getQuizMeta(lessonId);
    final nextResult = await _repo.getNextLesson(bookId, lesson.orderIndex);
    final enrolledResult = await _repo.isEnrolledInBook(bookId);

    final progress = progressResult.getOrElse(() => null);
    final quizMeta = quizMetaResult.getOrElse(() => const _EmptyQuizMeta());
    final nextLesson = nextResult.getOrElse(() => null);
    final isEnrolled = enrolledResult.getOrElse(() => false);

    // Prefetch the video stream URL so the player is ready by the time the
    // student opens the video tab (extraction runs while the page renders).
    if (lesson.hasVideo && lesson.videoUrl != null) {
      _videoStreamRepo.prefetch(lesson.videoUrl!);
    }

    emit(
      LessonLoaded(
        lesson: lesson,
        progress: progress,
        lessonHasQuiz: quizMeta.hasQuiz,
        isEnrolled: isEnrolled,
        hasQuizQuestions: quizMeta.questionCount > 0,
        quizQuestionCount: quizMeta.questionCount,
        quizAttemptsUsed: quizMeta.attemptsUsed,
        pastAttempts: quizMeta.pastAttempts,
        nextLessonId: nextLesson?.id,
        videoWatched: (progress?.videoPositionSeconds ?? 0) > 0,
      ),
    );
  }

  // The medium that drives completion for this lesson (video takes precedence).
  MediaType _primaryMediaType(bool hasVideo) =>
      hasVideo ? MediaType.video : MediaType.audio;

  // Called periodically from the video/audio tabs (rule L)
  Future<void> savePosition(int positionSeconds, MediaType type) async {
    if (positionSeconds <= 0) return; // don't overwrite a non-zero sentinel
    final current = state;
    if (current is! LessonLoaded) return;

    // Don't let an early tick right after re-entry clobber real progress: if we
    // already have a meaningful saved position for this medium, never move it
    // backwards.
    final currentSaved = type == MediaType.video
        ? current.videoPositionSeconds
        : current.audioPositionSeconds;
    if (positionSeconds < currentSaved && currentSaved > 30) return;

    await _repo.saveProgress(
      lessonId: current.lesson.id,
      mediaType: type,
      positionSeconds: positionSeconds,
      completed: current.isCompleted,
    );
  }

  // Called when video reaches ~90% or user taps "أنهيت المحاضرة" (rule L)
  Future<void> markVideoWatched() async {
    final current = state;
    if (current is! LessonLoaded || current.isCompleted) return;

    final shouldComplete = !current.hasQuizQuestions || current.quizAttempted;

    if (shouldComplete) {
      await _completeLesson(current);
    } else {
      // Quiz exists but not yet attempted — persist that the video was watched
      // so State 2 ("ابدأ الاختبار") survives a session restart.
      final mediaType = _primaryMediaType(current.lesson.hasVideo);
      final savedPosition = mediaType == MediaType.video
          ? current.videoPositionSeconds
          : current.audioPositionSeconds;
      final positionToSave = savedPosition > 0 ? savedPosition : 1;
      await _repo.saveProgress(
        lessonId: current.lesson.id,
        mediaType: mediaType,
        positionSeconds: positionToSave,
        completed: false,
      );
      // Also update in-memory progress so markQuizAttempted sees
      // hasVideoProgress = true and calls _completeLesson after the quiz.
      final existingProgress =
          current.progress ??
          LessonProgressEntity(
            id: '',
            userId: '',
            lessonId: current.lesson.id,
            completed: false,
          );
      final updatedProgress = mediaType == MediaType.video
          ? existingProgress.copyWith(videoPositionSeconds: positionToSave)
          : existingProgress.copyWith(audioPositionSeconds: positionToSave);
      emit(current.copyWith(videoWatched: true, progress: updatedProgress));
    }
  }

  // Called from quiz tab after grading (rule L)
  Future<void> markQuizAttempted(
    int attemptsUsed,
    LessonQuizAttemptEntity newAttempt,
  ) async {
    final current = state;
    if (current is! LessonLoaded) return;

    final updated = current.copyWith(
      quizAttemptsUsed: attemptsUsed,
      pastAttempts: [...current.pastAttempts, newAttempt],
    );
    emit(updated);

    final hasVideoProgress =
        current.progress != null && current.progress!.videoPositionSeconds > 0;
    final noVideo = !current.lesson.hasVideo;

    if (hasVideoProgress || noVideo) {
      await _completeLesson(updated);
    }
  }

  Future<void> _completeLesson(LessonLoaded current) async {
    emit(current.copyWith(isSavingProgress: true));

    // Completion is media-agnostic — it flips `completed`. We write back the
    // already-saved position for the primary medium (a no-op for position), which
    // never touches the other medium's column.
    final mediaType = _primaryMediaType(current.lesson.hasVideo);
    final savedPosition = mediaType == MediaType.video
        ? current.videoPositionSeconds
        : current.audioPositionSeconds;

    final result = await _repo.saveProgress(
      lessonId: current.lesson.id,
      mediaType: mediaType,
      positionSeconds: savedPosition,
      completed: true,
    );

    result.fold((_) => emit(current.copyWith(isSavingProgress: false)), (_) {
      final existingProgress =
          current.progress ??
          LessonProgressEntity(
            id: '',
            userId: '',
            lessonId: current.lesson.id,
            completed: false,
          );
      final updatedProgress = existingProgress.copyWith(
        completed: true,
        completedAt: existingProgress.completedAt ?? DateTime.now(),
      );

      emit(
        current.copyWith(isSavingProgress: false, progress: updatedProgress),
      );
    });
  }
}
