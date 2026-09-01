// lib/features/qa/data/qa_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/student_question_entity.dart';

class QaRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('QaRepository');

  QaRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, Unit>> askQuestion({
    required String bookId,
    required String lessonId,
    required String questionText,
  }) async {
    final networkError = _checkNetwork<Unit>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      await _client.from('student_questions').insert({
        'user_id': userId,
        'book_id': bookId,
        'lesson_id': lessonId,
        'question_text': questionText,
        'status': 'pending',
      });

      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('askQuestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<StudentQuestionEntity>>> getMyQuestions() async {
    final networkError = _checkNetwork<List<StudentQuestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('student_questions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      final questions = (response as List)
          .map((e) => StudentQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getMyQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-22: uses student_questions_public view (no user_id exposed)
  Future<Either<Failure, List<StudentQuestionEntity>>> getBookQuestions(
      String bookId) async {
    final networkError = _checkNetwork<List<StudentQuestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('student_questions_public')
          .select()
          .eq('book_id', bookId)
          .order('created_at', ascending: false)
          .limit(100);

      final questions = (response as List)
          .map((e) =>
              StudentQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getBookQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
