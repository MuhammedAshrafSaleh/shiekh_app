// lib/features/books/data/book_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/book_entity.dart';
import '../../../models/final_exam_attempt_entity.dart';
import '../../../models/lesson_entity.dart';
import '../../../models/lesson_progress_entity.dart';
import '../../../models/lesson_with_progress_entity.dart';

class BookRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('BookRepository');

  BookRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, BookEntity>> getBookDetails(String bookId) async {
    final networkError = _checkNetwork<BookEntity>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('books')
          .select()
          .eq('id', bookId)
          .single();
      return Right(BookEntity.fromJson(response));
    } on PostgrestException catch (e) {
      _log.warning('getBookDetails: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<LessonWithProgressEntity>>>
  getLessonsWithProgress(String bookId) async {
    final networkError = _checkNetwork<List<LessonWithProgressEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;

      // Use the URL-free metadata view so the full list renders for everyone.
      // The base `lessons` table is entitlement-gated (0006): guests / unenrolled
      // users only get media URLs for lesson 1 or enrolled books, via the player.
      final lessonsRaw = await _client
          .from('lessons_public')
          .select()
          .eq('book_id', bookId)
          .eq('status', 'published')
          .order('order_index', ascending: true)
          .limit(100);

      final lessonRows = (lessonsRaw as List).cast<Map<String, dynamic>>();
      final lessons = lessonRows.map((e) => LessonEntity.fromJson(e)).toList();

      if (lessons.isEmpty) return const Right([]);

      // Media + quiz presence flags come from the view (no URLs / no quiz
      // content exposed — booleans only, so they're accurate for guests too).
      final flagsById =
          <String, ({bool video, bool audio, bool pdf, bool quiz})>{};
      for (final row in lessonRows) {
        flagsById[row['id'] as String] = (
          video: (row['has_video'] as bool?) ?? false,
          audio: (row['has_audio'] as bool?) ?? false,
          pdf: (row['has_pdf'] as bool?) ?? false,
          quiz: (row['has_quiz'] as bool?) ?? false,
        );
      }

      final lessonIds = lessons.map((l) => l.id).toList();

      Map<String, LessonProgressEntity> progressMap = {};
      if (userId != null) {
        final progressRaw = await _client
            .from('lesson_progress')
            .select()
            .eq('user_id', userId)
            .inFilter('lesson_id', lessonIds)
            .limit(100);

        for (final row in (progressRaw as List)) {
          final p = LessonProgressEntity.fromJson(row as Map<String, dynamic>);
          progressMap[p.lessonId] = p;
        }
      }

      final result = lessons.map((lesson) {
        final flags = flagsById[lesson.id];
        return LessonWithProgressEntity(
          lesson: lesson,
          progress: progressMap[lesson.id],
          hasQuizQuestions: flags?.quiz ?? false,
          hasVideo: flags?.video ?? false,
          hasAudio: flags?.audio ?? false,
          hasPdf: flags?.pdf ?? false,
        );
      }).toList();

      return Right(result);
    } on PostgrestException catch (e) {
      _log.warning('getLessonsWithProgress: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, bool>> isEnrolled(String bookId) async {
    final networkError = _checkNetwork<bool>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Right(false);

      final response = await _client
          .from('enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .limit(1);

      return Right((response as List).isNotEmpty);
    } on PostgrestException catch (e) {
      _log.warning('isEnrolled: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-19: idempotent — insert with on-conflict ignore
  Future<Either<Failure, Unit>> enrollInBook(String bookId) async {
    final networkError = _checkNetwork<Unit>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      await _client
          .from('enrollments')
          .upsert(
            {'user_id': userId, 'book_id': bookId},
            onConflict: 'user_id,book_id',
            ignoreDuplicates: true,
          );

      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('enrollInBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Computes completion % using published lessons only (CC-1/CC-21)
  Future<Either<Failure, double>> getCompletionPercentage(String bookId) async {
    final networkError = _checkNetwork<double>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Right(0.0);

      // Metadata view returns all published lessons regardless of entitlement,
      // so the completion denominator stays correct for everyone (0006).
      final lessonsRaw = await _client
          .from('lessons_public')
          .select('id')
          .eq('book_id', bookId)
          .eq('status', 'published')
          .limit(200);

      final total = (lessonsRaw as List).length;
      if (total == 0) return const Right(0.0);

      final lessonIds = lessonsRaw.map((r) => r['id'] as String).toList();

      final progressRaw = await _client
          .from('lesson_progress')
          .select('lesson_id')
          .eq('user_id', userId)
          .eq('completed', true)
          .inFilter('lesson_id', lessonIds)
          .limit(200);

      final completed = (progressRaw as List).length;
      return Right(completed / total);
    } on PostgrestException catch (e) {
      _log.warning('getCompletionPercentage: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, FinalExamAttemptEntity?>> getBestExamAttempt(
    String bookId,
  ) async {
    final networkError = _checkNetwork<FinalExamAttemptEntity?>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Right(null);

      final response = await _client
          .from('final_exam_attempts')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('score_percentage', ascending: false)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(null);
      return Right(
        FinalExamAttemptEntity.fromJson(rows.first as Map<String, dynamic>),
      );
    } on PostgrestException catch (e) {
      _log.warning('getBestExamAttempt: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, bool>> hasFinalExam(String bookId) async {
    final networkError = _checkNetwork<bool>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('final_exam_settings')
          .select('is_published')
          .eq('book_id', bookId)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(false);
      return Right(rows.first['is_published'] as bool);
    } on PostgrestException catch (e) {
      _log.warning('hasFinalExam: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
