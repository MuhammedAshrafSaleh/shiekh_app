// lib/features/lesson/data/lesson_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/lesson_entity.dart';
import '../../../models/lesson_progress_entity.dart';
import '../../../models/quiz_question_entity.dart';

class QuizGradeResult {
  final int correct;
  final int total;
  final int percentage;

  const QuizGradeResult({
    required this.correct,
    required this.total,
    required this.percentage,
  });
}

class LessonRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('LessonRepository');

  LessonRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, LessonEntity>> getLesson(String lessonId) async {
    final networkError = _checkNetwork<LessonEntity>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('lessons')
          .select()
          .eq('id', lessonId)
          .single();
      return Right(LessonEntity.fromJson(response));
    } on PostgrestException catch (e) {
      _log.warning('getLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonProgressEntity?>> getLessonProgress(
      String lessonId) async {
    final networkError = _checkNetwork<LessonProgressEntity?>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Right(null);

      final response = await _client
          .from('lesson_progress')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(null);
      return Right(
          LessonProgressEntity.fromJson(rows.first as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      _log.warning('getLessonProgress: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-21: upsert on (user_id, lesson_id)
  Future<Either<Failure, Unit>> saveProgress({
    required String lessonId,
    required int lastPositionSeconds,
    required bool completed,
  }) async {
    final networkError = _checkNetwork<Unit>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final now = DateTime.now().toIso8601String();
      await _client.from('lesson_progress').upsert(
        {
          'user_id': userId,
          'lesson_id': lessonId,
          'completed': completed,
          'last_position_seconds': lastPositionSeconds,
          if (completed) 'completed_at': now,
          'updated_at': now,
        },
        onConflict: 'user_id,lesson_id',
      );

      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('saveProgress: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-18: uses lesson_quiz_questions_student view (no correct_choice)
  Future<Either<Failure, List<QuizQuestionEntity>>> getQuizQuestions(
      String lessonId) async {
    final networkError = _checkNetwork<List<QuizQuestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('lesson_quiz_questions_student')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index')
          .limit(50);

      final questions = (response as List)
          .map((e) =>
              QuizQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getQuizQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // Server-side grading (CC-18)
  Future<Either<Failure, QuizGradeResult>> gradeQuiz(
    String lessonId,
    Map<String, String> answers,
  ) async {
    final networkError = _checkNetwork<QuizGradeResult>();
    if (networkError != null) return networkError;

    try {
      final response = await _client.rpc('grade_lesson_quiz', params: {
        'p_lesson_id': lessonId,
        'p_answers': answers,
      });

      final data = response as Map<String, dynamic>;
      return Right(QuizGradeResult(
        correct: data['correct'] as int,
        total: data['total'] as int,
        percentage: data['percentage'] as int,
      ));
    } on PostgrestException catch (e) {
      _log.warning('gradeQuiz: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonEntity?>> getNextLesson(
      String bookId, int currentOrderIndex) async {
    final networkError = _checkNetwork<LessonEntity?>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('lessons')
          .select()
          .eq('book_id', bookId)
          .eq('status', 'published')
          .gt('order_index', currentOrderIndex)
          .order('order_index')
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(null);
      return Right(
          LessonEntity.fromJson(rows.first as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      _log.warning('getNextLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
