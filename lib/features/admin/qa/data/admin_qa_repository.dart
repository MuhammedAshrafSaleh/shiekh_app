// lib/features/admin/qa/data/admin_qa_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/student_question_entity.dart';

class AdminQaRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminQaRepository');

  AdminQaRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<StudentQuestionEntity>>> getQuestions({
    String? status, // 'pending' | 'answered' | null = all
    int limit = 50,
    int offset = 0,
  }) async {
    final net = _checkNetwork<List<StudentQuestionEntity>>();
    if (net != null) return net;
    try {
      var baseQuery = _client.from('student_questions').select();
      if (status != null) {
        baseQuery = baseQuery.eq('status', status);
      }
      final data = await baseQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return Right((data as List)
          .map((e) =>
              StudentQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, StudentQuestionEntity>> answerQuestion({
    required String questionId,
    required String answerText,
  }) async {
    final net = _checkNetwork<StudentQuestionEntity>();
    if (net != null) return net;
    try {
      final now = DateTime.now().toIso8601String();
      final data = await _client
          .from('student_questions')
          .update({
            'answer_text': answerText,
            'status': 'answered',
            'answered_at': now,
          })
          .eq('id', questionId)
          .select()
          .single();

      // Notify the asker — target_user_id scopes this to the asking student only
      try {
        _log.info('DEBUG answerQuestion: full data map = $data');
        _log.info('DEBUG answerQuestion: data[user_id] = ${data['user_id']}');
        await _client.from('notifications').insert({
          'type': 'general',
          'title': 'تمت الإجابة على سؤالك',
          'body': 'الشيخ أجاب على سؤالك في الكتاب',
          'send_at': now,
          'target_user_id': data['user_id'] as String,
        });
      } catch (e) {
        _log.warning('DEBUG answerQuestion: notification insert threw: $e');
      }

      return Right(StudentQuestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('answerQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Subscribe to new Q&A inserts (admin inbox realtime).
  RealtimeChannel subscribeToNewQuestions(
      void Function(Map<String, dynamic>) onInsert) {
    return _client
        .channel('admin:student_questions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'student_questions',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }
}
