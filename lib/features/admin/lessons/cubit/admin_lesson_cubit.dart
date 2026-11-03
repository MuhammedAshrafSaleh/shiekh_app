// lib/features/admin/lessons/cubit/admin_lesson_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/generation_job_entity.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/lesson_pdf_entity.dart';
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
    result.fold((f) => emit(AdminLessonListError(f.message)), (_) => refresh());
  }

  Future<bool> reorder(List<({String id, int orderIndex})> updates) async {
    final result = await _repo.reorderLessons(updates);
    return result.fold((_) => false, (_) => true);
  }

  Future<void> delete(String lessonId) async {
    final result = await _repo.deleteLesson(lessonId);
    result.fold((f) => emit(AdminLessonListError(f.message)), (_) => refresh());
  }
}

class AdminLessonFormCubit extends Cubit<AdminLessonFormState> {
  final AdminLessonRepository _repo;

  AdminLessonFormCubit(this._repo) : super(AdminLessonFormInitial());

  // Realtime channels powering the Quiz-tab status chip. Keyed 'form' so they
  // never collide with the generate page's own 'generate'-keyed channels on the
  // same rows (the generate page is pushed on top of this form).
  static const _kChipChannelKey = 'form';
  RealtimeChannel? _lessonChannel;
  RealtimeChannel? _jobChannel;
  String? _subscribedLessonId;
  String? _subscribedJobId;

  /// Surfaces a MUTATION failure (delete/add/update/approve/import/pdf) without
  /// blanking the screen: if we hold a loaded snapshot, re-emit it unchanged
  /// carrying a one-shot [transientError] (the UI shows a SnackBar and keeps the
  /// lists visible). Only a genuine load failure (no data to show) falls back to
  /// the full-screen [AdminLessonFormError].
  void _emitMutationError(AdminLessonFormState current, String message) {
    if (current is AdminLessonFormLoaded) {
      emit(
        AdminLessonFormLoaded(
          lesson: current.lesson,
          quizQuestions: current.quizQuestions,
          pdfs: current.pdfs,
          bankCount: current.bankCount,
          latestGenerationJob: current.latestGenerationJob,
          transientError: message,
          errorNonce: current.errorNonce + 1,
        ),
      );
    } else {
      emit(AdminLessonFormError(message));
    }
  }

  Future<void> load({String? lessonId}) async {
    emit(AdminLessonFormLoading());
    if (lessonId == null) {
      emit(const AdminLessonFormLoaded(lesson: null, quizQuestions: []));
      return;
    }
    final lessonResult = await _repo.getLesson(lessonId);
    await lessonResult.fold((f) async => emit(AdminLessonFormError(f.message)), (
      lesson,
    ) async {
      // Quiz questions, the bank count and the newest AI job are independent —
      // fetch concurrently.
      final (qResult, bankCountResult, jobResult) = await (
        _repo.getQuizQuestions(lessonId),
        _repo.getQuizBankQuestionsCount(
          bookId: lesson.bookId,
          excludeLessonId: lessonId,
        ),
        _repo.getLatestGenerationJob(lessonId),
      ).wait;
      final bankCount = bankCountResult.fold((_) => 0, (c) => c);
      final latestJob = jobResult.fold((_) => null, (j) => j);
      // PDFs come embedded with the lesson (getLesson selects lesson_pdfs(*)).
      // Sort a copy by order_index; show ALL rows so the admin can manage even
      // a (hypothetical) empty-url row that orderedPdfs would hide.
      final pdfs = [...lesson.pdfs]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      qResult.fold((f) => emit(AdminLessonFormError(f.message)), (qs) {
        emit(
          AdminLessonFormLoaded(
            lesson: lesson,
            quizQuestions: qs,
            pdfs: pdfs,
            bankCount: bankCount,
            latestGenerationJob: latestJob,
          ),
        );
        _syncChipSubscriptions(lesson, latestJob);
      });
    });
  }

  // ── Quiz-tab status chip (Realtime) ────────────────────────────────────────

  /// Subscribes to the lesson row while transcription is active and to the newest
  /// generation job while it is active, so the chip updates live. On any update
  /// it re-reads just those two single rows (no full reload, no spinner flash).
  void _syncChipSubscriptions(LessonEntity? lesson, GenerationJobEntity? job) {
    final lessonId = lesson?.id;
    final transcriptActive =
        lesson?.transcriptStatus == 'queued' ||
        lesson?.transcriptStatus == 'running';
    final jobActive = job?.isActive ?? false;

    if (transcriptActive &&
        lessonId != null &&
        _subscribedLessonId != lessonId) {
      _lessonChannel?.unsubscribe();
      _subscribedLessonId = lessonId;
      _lessonChannel = _repo.subscribeToLesson(
        lessonId,
        channelKey: _kChipChannelKey,
        onUpdate: (_) => _refreshChip(),
      );
    } else if (!transcriptActive && _lessonChannel != null) {
      _lessonChannel!.unsubscribe();
      _lessonChannel = null;
      _subscribedLessonId = null;
    }

    if (jobActive && job != null && _subscribedJobId != job.id) {
      _jobChannel?.unsubscribe();
      _subscribedJobId = job.id;
      _jobChannel = _repo.subscribeToGenerationJob(
        job.id,
        channelKey: _kChipChannelKey,
        onUpdate: (_) => _refreshChip(),
      );
    } else if (!jobActive && _jobChannel != null) {
      _jobChannel!.unsubscribe();
      _jobChannel = null;
      _subscribedJobId = null;
    }
  }

  /// Light refresh for the chip only: re-read the lesson row + newest job and
  /// re-emit the loaded snapshot with the heavier lists untouched.
  Future<void> _refreshChip() async {
    final current = state;
    if (current is! AdminLessonFormLoaded || current.lesson == null) return;
    final lessonId = current.lesson!.id;
    final (lessonRes, jobRes) = await (
      _repo.getLesson(lessonId),
      _repo.getLatestGenerationJob(lessonId),
    ).wait;
    if (isClosed) return;
    final cur = state;
    if (cur is! AdminLessonFormLoaded) return;
    final lesson = lessonRes.fold((_) => cur.lesson, (l) => l);
    final job = jobRes.fold((_) => cur.latestGenerationJob, (j) => j);
    emit(
      AdminLessonFormLoaded(
        lesson: lesson,
        quizQuestions: cur.quizQuestions,
        pdfs: cur.pdfs,
        bankCount: cur.bankCount,
        latestGenerationJob: job,
      ),
    );
    _syncChipSubscriptions(lesson, job);
  }

  /// Copies the selected bank questions into the current lesson, then reloads.
  Future<void> importFromBank(List<AdminQuizQuestionEntity> selected) async {
    final current = state;
    if (current is! AdminLessonFormLoaded || current.lesson == null) return;
    final lessonId = current.lesson!.id;
    final result = await _repo.importQuizBankQuestions(
      lessonId: lessonId,
      questions: selected,
    );
    result.fold(
      (f) => _emitMutationError(current, f.message),
      (_) => load(lessonId: lessonId),
    );
  }

  // pdfUrl is intentionally absent — PDFs are managed via the lesson_pdfs CRUD
  // methods below, and lessons.pdf_url is a DB-trigger mirror (migration 0012).
  Future<void> save({
    String? lessonId,
    required String bookId,
    required String title,
    String? description,
    String? videoUrl,
    String? audioUrl,
    required bool audioOnly,
    required String status,
    int? videoDurationMinutes,
    int? audioDurationMinutes,
  }) async {
    final current = state;
    emit(AdminLessonFormSaving());
    final result = lessonId == null
        ? await _repo.createLesson(
            bookId: bookId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
            audioOnly: audioOnly,
            status: status,
            videoDurationMinutes: videoDurationMinutes,
            audioDurationMinutes: audioDurationMinutes,
          )
        : await _repo.updateLesson(
            id: lessonId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            audioUrl: audioUrl,
            audioOnly: audioOnly,
            status: status,
            videoDurationMinutes: videoDurationMinutes,
            audioDurationMinutes: audioDurationMinutes,
          );
    result.fold(
      (f) => _emitMutationError(current, f.message),
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
    result.fold((f) => _emitMutationError(current, f.message), (q) {
      if (current is AdminLessonFormLoaded) {
        emit(
          AdminLessonFormLoaded(
            lesson: current.lesson,
            quizQuestions: [...current.quizQuestions, q],
            pdfs: current.pdfs,
            bankCount: current.bankCount,
            latestGenerationJob: current.latestGenerationJob,
          ),
        );
      }
    });
  }

  Future<void> updateQuizQuestion({
    required String questionId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
    bool markReviewed = false,
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
      markReviewed: markReviewed,
    );
    result.fold((f) => _emitMutationError(current, f.message), (updated) {
      if (current is AdminLessonFormLoaded) {
        final qs = current.quizQuestions
            .map((q) => q.id == updated.id ? updated : q)
            .toList();
        emit(
          AdminLessonFormLoaded(
            lesson: current.lesson,
            quizQuestions: qs,
            pdfs: current.pdfs,
            bankCount: current.bankCount,
            latestGenerationJob: current.latestGenerationJob,
          ),
        );
      }
    });
  }

  /// Approves a single pending AI question and swaps the reviewed row in place.
  Future<void> approveQuizQuestion(String questionId) async {
    final current = state;
    final result = await _repo.approveQuestion(questionId);
    result.fold((f) => _emitMutationError(current, f.message), (updated) {
      if (current is AdminLessonFormLoaded) {
        final qs = current.quizQuestions
            .map((q) => q.id == updated.id ? updated : q)
            .toList();
        emit(
          AdminLessonFormLoaded(
            lesson: current.lesson,
            quizQuestions: qs,
            pdfs: current.pdfs,
            bankCount: current.bankCount,
            latestGenerationJob: current.latestGenerationJob,
          ),
        );
      }
    });
  }

  /// Bulk-approves every pending AI question in the current lesson, then reloads.
  Future<void> approveAllPending() async {
    final current = state;
    if (current is! AdminLessonFormLoaded || current.lesson == null) return;
    final lessonId = current.lesson!.id;
    final result = await _repo.approveAllForLesson(lessonId);
    result.fold(
      (f) => _emitMutationError(current, f.message),
      (_) => load(lessonId: lessonId),
    );
  }

  Future<void> deleteQuizQuestion(String questionId) async {
    final current = state;
    final result = await _repo.deleteQuizQuestion(questionId);
    result.fold((f) => _emitMutationError(current, f.message), (_) {
      if (current is AdminLessonFormLoaded) {
        final qs = current.quizQuestions
            .where((q) => q.id != questionId)
            .toList();
        emit(
          AdminLessonFormLoaded(
            lesson: current.lesson,
            quizQuestions: qs,
            pdfs: current.pdfs,
            bankCount: current.bankCount,
            latestGenerationJob: current.latestGenerationJob,
            transientSuccess: 'تم حذف السؤال',
            successNonce: current.successNonce + 1,
          ),
        );
      }
    });
  }

  // ── Lesson PDFs (migration 0012) ──────────────────────────────────────────
  //
  // Same immediate-mutation pattern as the quiz-question methods: each requires
  // a SAVED lessonId (the UI gates add behind a saved lesson), calls the repo,
  // and on success emits an updated AdminLessonFormLoaded with the new pdfs list
  // — no full-lesson refetch. A helper rebuilds the loaded state preserving the
  // other fields.

  void _emitPdfs(AdminLessonFormLoaded current, List<LessonPdfEntity> pdfs) {
    emit(
      AdminLessonFormLoaded(
        lesson: current.lesson,
        quizQuestions: current.quizQuestions,
        pdfs: pdfs,
        bankCount: current.bankCount,
        latestGenerationJob: current.latestGenerationJob,
      ),
    );
  }

  Future<void> addLessonPdf({
    required String lessonId,
    required String title,
    required String url,
  }) async {
    final current = state;
    final result = await _repo.createLessonPdf(
      lessonId: lessonId,
      title: title,
      url: url,
    );
    result.fold((f) => _emitMutationError(current, f.message), (pdf) {
      if (current is AdminLessonFormLoaded) {
        _emitPdfs(current, [...current.pdfs, pdf]);
      }
    });
  }

  Future<void> updateLessonPdf({
    required String id,
    required String title,
    required String url,
  }) async {
    final current = state;
    final result = await _repo.updateLessonPdf(id: id, title: title, url: url);
    result.fold((f) => _emitMutationError(current, f.message), (updated) {
      if (current is AdminLessonFormLoaded) {
        final pdfs = current.pdfs
            .map((p) => p.id == updated.id ? updated : p)
            .toList();
        _emitPdfs(current, pdfs);
      }
    });
  }

  Future<void> deleteLessonPdf(String id) async {
    final current = state;
    final result = await _repo.deleteLessonPdf(id);
    result.fold((f) => _emitMutationError(current, f.message), (_) {
      if (current is AdminLessonFormLoaded) {
        _emitPdfs(current, current.pdfs.where((p) => p.id != id).toList());
      }
    });
  }

  /// Persists a new PDF order. [ordered] is the full list in its new sequence;
  /// order_index is rewritten contiguously (0..n-1). Emits optimistically so the
  /// drag feels instant, then persists. On failure it REVERTS to the pre-reorder
  /// order (captured in [current] before the optimistic emit) so state stays
  /// consistent with the server — the snap-back is the failure signal. We
  /// deliberately don't emit AdminLessonFormError here, which would blank the
  /// loaded lists (the builder falls back to empty when state isn't Loaded).
  Future<void> reorderLessonPdfs(List<LessonPdfEntity> ordered) async {
    final current = state;
    if (current is! AdminLessonFormLoaded) return;
    final reindexed = [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(orderIndex: i),
    ];
    _emitPdfs(current, reindexed);
    final updates = [
      for (final p in reindexed) (id: p.id, orderIndex: p.orderIndex),
    ];
    final result = await _repo.reorderLessonPdfs(updates);
    result.fold((_) => _emitPdfs(current, current.pdfs), (_) {});
  }

  @override
  Future<void> close() async {
    await _lessonChannel?.unsubscribe();
    await _jobChannel?.unsubscribe();
    return super.close();
  }
}
