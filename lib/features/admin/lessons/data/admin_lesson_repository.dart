// lib/features/admin/lessons/data/admin_lesson_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/lesson_entity.dart';

class AdminLessonRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminLessonRepository');

  AdminLessonRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<LessonEntity>>> getLessons(
      String bookId) async {
    final net = _checkNetwork<List<LessonEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lessons')
          .select()
          .eq('book_id', bookId)
          .order('order_index')
          .limit(200);
      return Right((data as List)
          .map((e) => LessonEntity.fromJson(e as Map<String, dynamic>))
          .toList());
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
      final data = await _client
          .from('lessons')
          .select()
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

  Future<Either<Failure, LessonEntity>> createLesson({
    required String bookId,
    required String title,
    String? description,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
    required bool audioOnly,
    required String status,
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
          : ((existingList.first as Map<String, dynamic>)['order_index'] as int) +
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
            'pdf_url': pdfUrl,
            'audio_only': audioOnly,
            'status': status,
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

  Future<Either<Failure, LessonEntity>> updateLesson({
    required String id,
    required String title,
    String? description,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
    required bool audioOnly,
    required String status,
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
            'pdf_url': pdfUrl,
            'audio_only': audioOnly,
            'status': status,
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
      String lessonId, bool publish) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('lessons').update({
        'status': publish ? 'published' : 'draft',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lessonId);
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
      List<({String id, int orderIndex})> updates) async {
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

  // ── Quiz questions (admin — includes correct_choice) ──────────────────────

  Future<Either<Failure, List<AdminQuizQuestionEntity>>> getQuizQuestions(
      String lessonId) async {
    final net = _checkNetwork<List<AdminQuizQuestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lesson_quiz_questions')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index')
          .limit(50);
      return Right((data as List)
          .map((e) =>
              AdminQuizQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList());
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

  Future<Either<Failure, AdminQuizQuestionEntity>> updateQuizQuestion({
    required String id,
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
      final data = await _client
          .from('lesson_quiz_questions')
          .update({
            'question_text': questionText,
            'choice_a': choiceA,
            'choice_b': choiceB,
            'choice_c': choiceC,
            'choice_d': choiceD,
            'correct_choice': correctChoice,
          })
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

  Future<Either<Failure, Unit>> deleteQuizQuestion(String questionId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('lesson_quiz_questions')
          .delete()
          .eq('id', questionId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteQuizQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
