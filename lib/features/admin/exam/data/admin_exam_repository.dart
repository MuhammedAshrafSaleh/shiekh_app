// lib/features/admin/exam/data/admin_exam_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/admin_final_exam_question_entity.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/final_exam_settings_entity.dart';

class AdminExamRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminExamRepository');

  AdminExamRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<Either<Failure, FinalExamSettingsEntity?>> getSettings(
    String bookId,
  ) async {
    final net = _checkNetwork<FinalExamSettingsEntity?>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('final_exam_settings')
          .select()
          .eq('book_id', bookId)
          .limit(1);
      final rows = data as List;
      if (rows.isEmpty) return const Right(null);
      return Right(
        FinalExamSettingsEntity.fromJson(rows.first as Map<String, dynamic>),
      );
    } on PostgrestException catch (e) {
      _log.warning('getSettings: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, FinalExamSettingsEntity>> upsertSettings({
    required String bookId,
    required int timeLimitMinutes,
    required int passingPercentage,
    required int maxAttempts,
    required bool isPublished,
  }) async {
    final net = _checkNetwork<FinalExamSettingsEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('final_exam_settings')
          .upsert({
            'book_id': bookId,
            'time_limit_minutes': timeLimitMinutes,
            'passing_percentage': passingPercentage,
            'max_attempts': maxAttempts,
            'is_published': isPublished,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'book_id')
          .select()
          .single();
      return Right(FinalExamSettingsEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('upsertSettings: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  Future<Either<Failure, List<AdminFinalExamQuestionEntity>>> getQuestions(
    String bookId,
  ) async {
    final net = _checkNetwork<List<AdminFinalExamQuestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('final_exam_questions')
          .select()
          .eq('book_id', bookId)
          .order('order_index', ascending: true)
          .limit(200);
      return Right(
        (data as List)
            .map(
              (e) => AdminFinalExamQuestionEntity.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, AdminFinalExamQuestionEntity>> createQuestion({
    required String bookId,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
    String? sourceQuizQuestionId,
  }) async {
    final net = _checkNetwork<AdminFinalExamQuestionEntity>();
    if (net != null) return net;
    try {
      final existing = await _client
          .from('final_exam_questions')
          .select('order_index')
          .eq('book_id', bookId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingList = existing as List;
      final nextOrder = existingList.isEmpty
          ? 0
          : ((existingList.first as Map<String, dynamic>)['order_index']
                    as int) +
                1;

      final data = await _client
          .from('final_exam_questions')
          .insert({
            'book_id': bookId,
            'order_index': nextOrder,
            'question_text': questionText,
            'choice_a': choiceA,
            'choice_b': choiceB,
            'choice_c': choiceC,
            'choice_d': choiceD,
            'correct_choice': correctChoice,
            'source_quiz_question_id': sourceQuizQuestionId,
          })
          .select()
          .single();
      return Right(AdminFinalExamQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, AdminFinalExamQuestionEntity>> updateQuestion({
    required String id,
    required String questionText,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String choiceD,
    required String correctChoice,
  }) async {
    final net = _checkNetwork<AdminFinalExamQuestionEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('final_exam_questions')
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
      return Right(AdminFinalExamQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteQuestion(String questionId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('final_exam_questions').delete().eq('id', questionId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> reorderQuestions(
    List<(String id, int orderIndex)> updates,
  ) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      for (final (id, orderIndex) in updates) {
        await _client
            .from('final_exam_questions')
            .update({'order_index': orderIndex})
            .eq('id', id);
      }
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('reorderQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Quiz bank questions from all lessons of a book — approved only, so
  /// unreviewed AI-generated questions never reach the exam.
  Future<Either<Failure, List<AdminQuizQuestionEntity>>> getBankQuestions(
    String bookId,
  ) async {
    final net = _checkNetwork<List<AdminQuizQuestionEntity>>();
    if (net != null) return net;
    try {
      // Join through lessons
      final data = await _client
          .from('lesson_quiz_questions')
          .select('*, lessons!inner(book_id)')
          .eq('lessons.book_id', bookId)
          .eq('ai_review_status', 'approved')
          .order('order_index', ascending: true)
          .limit(200);
      return Right(
        (data as List)
            .map(
              (e) =>
                  AdminQuizQuestionEntity.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getBankQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Count of approved bank questions for [bookId] — a lightweight head query
  /// (exact count, no rows fetched) used only for the import button label.
  Future<Either<Failure, int>> getBankQuestionsCount(String bookId) async {
    final net = _checkNetwork<int>();
    if (net != null) return net;
    try {
      final res = await _client
          .from('lesson_quiz_questions')
          .select('id, lessons!inner(book_id)')
          .eq('lessons.book_id', bookId)
          .eq('ai_review_status', 'approved')
          .limit(1)
          .count(CountOption.exact);
      return Right(res.count);
    } on PostgrestException catch (e) {
      _log.warning('getBankQuestionsCount: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Import selected questions from bank into final exam.
  Future<Either<Failure, int>> importBankQuestions({
    required String bookId,
    required List<AdminQuizQuestionEntity> questions,
  }) async {
    final net = _checkNetwork<int>();
    if (net != null) return net;
    try {
      // Get current max order_index
      final existing = await _client
          .from('final_exam_questions')
          .select('order_index')
          .eq('book_id', bookId)
          .order('order_index', ascending: false)
          .limit(1);
      final existingImport = existing as List;
      int nextOrder = existingImport.isEmpty
          ? 0
          : ((existingImport.first as Map<String, dynamic>)['order_index']
                    as int) +
                1;

      final rows = questions
          .map(
            (q) => {
              'book_id': bookId,
              'order_index': nextOrder++,
              'question_text': q.questionText,
              'choice_a': q.choiceA,
              'choice_b': q.choiceB,
              'choice_c': q.choiceC,
              'choice_d': q.choiceD,
              'correct_choice': q.correctChoice,
              'source_quiz_question_id': q.id,
            },
          )
          .toList();

      await _client.from('final_exam_questions').insert(rows);
      return Right(rows.length);
    } on PostgrestException catch (e) {
      _log.warning('importBankQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
