// lib/features/admin/lessons/data/admin_lesson_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
// http is a transitive dep of supabase_flutter (functions_client); imported
// only to catch transport-level ClientException on the AI Edge Function calls.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' show ClientException;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/generation_job_entity.dart';
import '../../../../models/job_enqueue_entity.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/lesson_pdf_entity.dart';

/// Shown when the Edge Functions report no AI key is configured
/// (`AI_KEY_MISSING`). The admin sets it in الإعدادات ← مفتاح الذكاء الاصطناعي.
const String _kAiKeyMissingMessage =
    'لم يتم ضبط مفتاح الذكاء الاصطناعي. أضِفه من الإعدادات أولاً.';

class AdminLessonRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminLessonRepository');

  AdminLessonRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<LessonEntity>>> getLessons(String bookId) async {
    final net = _checkNetwork<List<LessonEntity>>();
    if (net != null) return net;
    try {
      // Embed only PDF ids (migration 0012): enough for the list's PDF icon,
      // which derives lesson.hasPdf from the embedded list length — driven by the
      // actual child rows, not the deprecated pdf_url mirror. LessonPdfEntity
      // tolerates this partial (id-only) embed.
      final data = await _client
          .from('lessons')
          .select('*, lesson_pdfs(id)')
          .eq('book_id', bookId)
          .order('order_index', ascending: true)
          .limit(200);
      return Right(
        (data as List)
            .map((e) => LessonEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getLessons: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonEntity>> getLesson(String lessonId) async {
    final net = _checkNetwork<LessonEntity>();
    if (net != null) return net;
    try {
      // Embed the lesson's PDFs (migration 0012) so the form loads them.
      final data = await _client
          .from('lessons')
          .select('*, lesson_pdfs(*)')
          .eq('id', lessonId)
          .single();
      return Right(LessonEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('getLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // NOTE: pdf_url is NOT written here (migration 0012). It is a DEPRECATED
  // auto-mirror of the first lesson_pdfs row, maintained solely by the DB
  // trigger. PDFs are managed via the lesson_pdfs CRUD methods below.
  Future<Either<Failure, LessonEntity>> createLesson({
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
    final net = _checkNetwork<LessonEntity>();
    if (net != null) return net;
    try {
      // Determine next order_index
      final existing = await _client
          .from('lessons')
          .select('order_index')
          .eq('book_id', bookId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingList = existing as List;
      final nextOrder = existingList.isEmpty
          ? 1
          : ((existingList.first as Map<String, dynamic>)['order_index']
                    as int) +
                1;

      final data = await _client
          .from('lessons')
          .insert({
            'book_id': bookId,
            'order_index': nextOrder,
            'title': title,
            'description': description,
            'video_url': videoUrl,
            'audio_url': audioUrl,
            'audio_only': audioOnly,
            'status': status,
            'video_duration_minutes': videoDurationMinutes,
            'audio_duration_minutes': audioDurationMinutes,
          })
          .select()
          .single();
      return Right(LessonEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // NOTE: pdf_url is NOT written here — see createLesson (migration 0012).
  Future<Either<Failure, LessonEntity>> updateLesson({
    required String id,
    required String title,
    String? description,
    String? videoUrl,
    String? audioUrl,
    required bool audioOnly,
    required String status,
    int? videoDurationMinutes,
    int? audioDurationMinutes,
  }) async {
    final net = _checkNetwork<LessonEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lessons')
          .update({
            'title': title,
            'description': description,
            'video_url': videoUrl,
            'audio_url': audioUrl,
            'audio_only': audioOnly,
            'status': status,
            'video_duration_minutes': videoDurationMinutes,
            'audio_duration_minutes': audioDurationMinutes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Right(LessonEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteLesson(String lessonId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('lessons').delete().eq('id', lessonId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> togglePublish(
    String lessonId,
    bool publish,
  ) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('lessons')
          .update({
            'status': publish ? 'published' : 'draft',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', lessonId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('togglePublish: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// CC-5: transactional reorder — delegates to the reorder_lessons RPC
  /// (added in 0002_hardening.sql) so all order_index updates run inside a
  /// single server-side transaction; a partial network failure cannot leave
  /// the order table in an inconsistent state.
  Future<Either<Failure, Unit>> reorderLessons(
    List<({String id, int orderIndex})> updates,
  ) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      final payload = updates
          .map((u) => {'id': u.id, 'order_index': u.orderIndex})
          .toList();
      await _client.rpc('reorder_lessons', params: {'p_updates': payload});
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('reorderLessons: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // ── Lesson PDFs (migration 0012) ──────────────────────────────────────────
  // The form loads PDFs embedded via getLesson (lesson_pdfs(*)); the cubit then
  // maintains the list locally through these mutations, so there is no separate
  // getLessonPdfs fetch.

  Future<Either<Failure, LessonPdfEntity>> createLessonPdf({
    required String lessonId,
    required String title,
    required String url,
  }) async {
    final net = _checkNetwork<LessonPdfEntity>();
    if (net != null) return net;
    try {
      // Append after any existing PDFs.
      final existing = await _client
          .from('lesson_pdfs')
          .select('order_index')
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingList = existing as List;
      final nextOrder = existingList.isEmpty
          ? 0
          : ((existingList.first as Map<String, dynamic>)['order_index']
                    as int) +
                1;

      final data = await _client
          .from('lesson_pdfs')
          .insert({
            'lesson_id': lessonId,
            'title': title,
            'url': url,
            'order_index': nextOrder,
          })
          .select()
          .single();
      return Right(LessonPdfEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createLessonPdf: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonPdfEntity>> updateLessonPdf({
    required String id,
    required String title,
    required String url,
  }) async {
    final net = _checkNetwork<LessonPdfEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lesson_pdfs')
          .update({'title': title, 'url': url})
          .eq('id', id)
          .select()
          .single();
      return Right(LessonPdfEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateLessonPdf: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteLessonPdf(String id) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('lesson_pdfs').delete().eq('id', id);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteLessonPdf: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Row-by-row order_index rewrite. Safe without a transaction/RPC: there is no
  /// unique(lesson_id, order_index) constraint (migration 0012), so intermediate
  /// duplicate indices during the rewrite cannot collide. Callers pass a fully
  /// renumbered, contiguous list.
  Future<Either<Failure, Unit>> reorderLessonPdfs(
    List<({String id, int orderIndex})> updates,
  ) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      for (final u in updates) {
        await _client
            .from('lesson_pdfs')
            .update({'order_index': u.orderIndex})
            .eq('id', u.id);
      }
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('reorderLessonPdfs: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // ── Quiz questions (admin — includes correct_choice) ──────────────────────

  Future<Either<Failure, List<AdminQuizQuestionEntity>>> getQuizQuestions(
    String lessonId,
  ) async {
    final net = _checkNetwork<List<AdminQuizQuestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lesson_quiz_questions')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: true)
          .limit(50);
      return Right(
        (data as List)
            .map(
              (e) =>
                  AdminQuizQuestionEntity.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getQuizQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, AdminQuizQuestionEntity>> createQuizQuestion({
    required String lessonId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    final net = _checkNetwork<AdminQuizQuestionEntity>();
    if (net != null) return net;
    try {
      final existing = await _client
          .from('lesson_quiz_questions')
          .select('order_index')
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingQs = existing as List;
      final nextOrder = existingQs.isEmpty
          ? 0
          : ((existingQs.first as Map<String, dynamic>)['order_index'] as int) +
                1;

      final data = await _client
          .from('lesson_quiz_questions')
          .insert({
            'lesson_id': lessonId,
            'order_index': nextOrder,
            'question_text': questionText,
            'choice_a': choiceA,
            'choice_b': choiceB,
            'choice_c': choiceC,
            'choice_d': choiceD,
            'correct_choice': correctChoice,
          })
          .select()
          .single();
      return Right(AdminQuizQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createQuizQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Updates a question's content. When [markReviewed] is true (editing a
  /// pending AI question), the same write also approves it and records it as
  /// admin-edited — one round-trip. Manual edits leave [markReviewed] false so
  /// source/review status are untouched.
  Future<Either<Failure, AdminQuizQuestionEntity>> updateQuizQuestion({
    required String id,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
    bool markReviewed = false,
  }) async {
    final net = _checkNetwork<AdminQuizQuestionEntity>();
    if (net != null) return net;
    try {
      final payload = <String, dynamic>{
        'question_text': questionText,
        'choice_a': choiceA,
        'choice_b': choiceB,
        'choice_c': choiceC,
        'choice_d': choiceD,
        'correct_choice': correctChoice,
      };
      if (markReviewed) {
        payload['source'] = 'edited_by_admin';
        payload['ai_review_status'] = 'approved';
        payload['reviewed_by'] = _client.auth.currentUser?.id;
        payload['reviewed_at'] = DateTime.now().toIso8601String();
      }
      final data = await _client
          .from('lesson_quiz_questions')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return Right(AdminQuizQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateQuizQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Approves a single pending AI question, stamping the reviewer + time.
  Future<Either<Failure, AdminQuizQuestionEntity>> approveQuestion(
    String id,
  ) async {
    final net = _checkNetwork<AdminQuizQuestionEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lesson_quiz_questions')
          .update({
            'ai_review_status': 'approved',
            'reviewed_by': _client.auth.currentUser?.id,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Right(AdminQuizQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('approveQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Bulk-approves every still-pending AI question in a lesson.
  Future<Either<Failure, Unit>> approveAllForLesson(String lessonId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('lesson_quiz_questions')
          .update({
            'ai_review_status': 'approved',
            'reviewed_by': _client.auth.currentUser?.id,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('lesson_id', lessonId)
          .eq('ai_review_status', 'pending');
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('approveAllForLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteQuizQuestion(String questionId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('lesson_quiz_questions').delete().eq('id', questionId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteQuizQuestion: ${e.code} ${e.message}');
      // 23503 = FK violation (question still referenced, e.g. imported into a
      // final exam). Never surface the raw Postgres text.
      if (e.code == '23503') {
        return Left(
          ServerFailure('لا يمكن حذف هذا السؤال لأنه مُستخدم في مكان آخر.'),
        );
      }
      return Left(ServerFailure('تعذّر حذف السؤال، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Count of importable bank questions from the book's other lessons — a
  /// lightweight head query used only for the import button label. Shares the
  /// drill-down's predicate (approved originals, current lesson excluded).
  Future<Either<Failure, int>> getQuizBankQuestionsCount({
    required String bookId,
    required String excludeLessonId,
  }) async {
    final net = _checkNetwork<int>();
    if (net != null) return net;
    try {
      final res = await _client
          .from('lesson_quiz_questions')
          .select('id, lessons!inner(book_id)')
          .eq('lessons.book_id', bookId)
          .eq('ai_review_status', 'approved')
          .isFilter('source_question_id', null) // originals only (excl. copies)
          .neq('lesson_id', excludeLessonId)
          .limit(1)
          .count(CountOption.exact);
      return Right(res.count);
    } on PostgrestException catch (e) {
      _log.warning('getQuizBankQuestionsCount: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Copies selected bank questions into [lessonId]'s quiz, appended after any
  /// existing questions. Returns the number of rows inserted.
  Future<Either<Failure, int>> importQuizBankQuestions({
    required String lessonId,
    required List<AdminQuizQuestionEntity> questions,
  }) async {
    final net = _checkNetwork<int>();
    if (net != null) return net;
    try {
      final existing = await _client
          .from('lesson_quiz_questions')
          .select('order_index')
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingList = existing as List;
      int nextOrder = existingList.isEmpty
          ? 0
          : ((existingList.first as Map<String, dynamic>)['order_index']
                    as int) +
                1;

      final rows = questions
          .map(
            (q) => {
              'lesson_id': lessonId,
              'order_index': nextOrder++,
              'question_text': q.questionText,
              'choice_a': q.choiceA,
              'choice_b': q.choiceB,
              'choice_c': q.choiceC,
              'choice_d': q.choiceD,
              'correct_choice': q.correctChoice,
              // Provenance link (migration 0019): marks this row as a copy so it
              // is excluded from the bank and shown as "تمت الإضافة".
              'source_question_id': q.id,
            },
          )
          .toList();

      await _client.from('lesson_quiz_questions').insert(rows);
      return Right(rows.length);
    } on PostgrestException catch (e) {
      _log.warning('importQuizBankQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // ── AI question generation (generate-questions Edge Function) ──────────────

  /// Enqueues question generation via the `generate-questions` Edge Function.
  /// Under the async-queue contract the function returns HTTP 202
  /// `{ job_id, status: 'queued' }` in ~1 s and never returns the questions —
  /// the work runs in a background worker (up to 12 retries over ~8 h). Progress
  /// is tracked on `public.generation_jobs` by the returned [JobEnqueueEntity.jobId]
  /// (see [getLatestGenerationJob] / [subscribeToGenerationJob]). 202 is SUCCESS;
  /// only a genuine 4xx/5xx is an error. The admin JWT is attached automatically.
  Future<Either<Failure, JobEnqueueEntity>> generateQuestions({
    required String lessonId,
    required String transcriptText,
    required int requestedCount,
    required Map<String, int> difficultyMix,
  }) async {
    final net = _checkNetwork<JobEnqueueEntity>();
    if (net != null) return net;
    try {
      final res = await _client.functions.invoke(
        'generate-questions',
        body: {
          'lesson_id': lessonId,
          'transcript_text': transcriptText,
          'requested_count': requestedCount,
          'difficulty_mix': difficultyMix,
        },
      );
      return _parseEnqueueAck(res, context: 'generateQuestions');
    } on FunctionException catch (e) {
      return Left(_mapAiFunctionException(e, context: 'generateQuestions'));
    } on ClientException catch (e) {
      _log.warning('generateQuestions transport: $e');
      return Left(NetworkFailure('انقطع الاتصال أثناء الطلب، حاول مرة أخرى'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Enqueues transcription via the `transcribe-lesson` Edge Function. Returns
  /// HTTP 202 `{ job_id, status: 'queued' }` in ~2 s; the transcript itself is
  /// never returned — progress lives on `public.lessons` (`transcript_status`,
  /// `transcript_error`, `transcript`), watched via [subscribeToLesson] / a
  /// re-fetch of [getLesson]. 202 is SUCCESS; only a genuine 4xx/5xx is an error.
  Future<Either<Failure, JobEnqueueEntity>> transcribeLesson({
    required String lessonId,
    required String sourceType, // 'youtube' | 'drive_audio'
    required String sourceUrl,
  }) async {
    final net = _checkNetwork<JobEnqueueEntity>();
    if (net != null) return net;
    try {
      final res = await _client.functions.invoke(
        'transcribe-lesson',
        body: {
          'lesson_id': lessonId,
          'source_type': sourceType,
          'source_url': sourceUrl,
        },
      );
      return _parseEnqueueAck(res, context: 'transcribeLesson');
    } on FunctionException catch (e) {
      return Left(_mapAiFunctionException(e, context: 'transcribeLesson'));
    } on ClientException catch (e) {
      _log.warning('transcribeLesson transport: $e');
      return Left(NetworkFailure('انقطع الاتصال أثناء الطلب، حاول مرة أخرى'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Decodes a 2xx enqueue acknowledgement. `functions.invoke` returns a normal
  /// [FunctionResponse] for any 200–299 status (incl. 202), so the ack arrives
  /// here, not via [FunctionException]. [FunctionResponse.data] is a decoded Map
  /// only when the function sent `Content-Type: application/json`; guard against
  /// a String/empty body rather than a blind cast.
  Either<Failure, JobEnqueueEntity> _parseEnqueueAck(
    FunctionResponse res, {
    required String context,
  }) {
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      _log.warning('$context: unexpected non-JSON ack body (${res.status})');
      return Left(ServerFailure('تعذّر بدء العملية، يرجى المحاولة مرة أخرى'));
    }
    return Right(JobEnqueueEntity.fromJson(data));
  }

  /// Maps a genuine non-2xx from the AI Edge Functions. `details` is the decoded
  /// response body, typically `{ error: '...' }`.
  Failure _mapAiFunctionException(
    FunctionException e, {
    required String context,
  }) {
    final details = e.details;
    final code = (details is Map) ? details['error']?.toString() : null;
    if (code == 'AI_KEY_MISSING') {
      _log.warning('$context: AI key missing');
      return ValidationFailure(_kAiKeyMissingMessage);
    }
    // 503, RESOURCE_EXHAUSTED, OVERLOADED, or deadline_exceeded all indicate AI
    // service saturation — not a logic error in the request.
    if (e.status == 503 ||
        code == 'RESOURCE_EXHAUSTED' ||
        code == 'OVERLOADED' ||
        (code != null && code.contains('deadline_exceeded'))) {
      final msg = code ?? 'الخدمة مشغولة حالياً، حاول مرة أخرى';
      _log.warning('$context overload http ${e.status}: $msg');
      return AiOverloadFailure(msg);
    }
    final msg = code ?? 'تعذّر تنفيذ الطلب، يرجى المحاولة مرة أخرى';
    _log.warning('$context http ${e.status}: $msg');
    return ServerFailure(msg);
  }

  // ── AI job tracking (async-queue contract) ─────────────────────────────────

  /// The newest `generate_questions` job for a lesson, or null if none exists.
  /// Read on page/tab open to re-derive the true current status (the UI is
  /// resumable across app restarts), and as the Realtime poll fallback.
  Future<Either<Failure, GenerationJobEntity?>> getLatestGenerationJob(
    String lessonId,
  ) async {
    final net = _checkNetwork<GenerationJobEntity?>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('generation_jobs')
          .select()
          .eq('lesson_id', lessonId)
          .eq('job_type', 'generate_questions')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return Right(data == null ? null : GenerationJobEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('getLatestGenerationJob: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Subscribes to UPDATEs on a single `lessons` row (transcription progress).
  ///
  /// [channelKey] disambiguates the topic so two cubits can watch the SAME row
  /// at once without colliding — the form cubit (Quiz-tab chip) and the generate
  /// cubit are both live when the generate page is pushed over the form. Pass a
  /// per-owner key like 'form' vs 'generate'.
  RealtimeChannel subscribeToLesson(
    String lessonId, {
    required String channelKey,
    required void Function(Map<String, dynamic> row) onUpdate,
  }) {
    return _client
        .channel('lesson:$lessonId:$channelKey')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lessons',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: lessonId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribes to UPDATEs on a single `generation_jobs` row (question-gen
  /// progress). See [subscribeToLesson] for the [channelKey] contract.
  RealtimeChannel subscribeToGenerationJob(
    String jobId, {
    required String channelKey,
    required void Function(Map<String, dynamic> row) onUpdate,
  }) {
    return _client
        .channel('genjob:$jobId:$channelKey')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'generation_jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
