// lib/features/admin/stats/data/admin_stats_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/student_question_entity.dart';

class BookStats {
  final int totalStudents;
  final int completedStudents;
  final double completionRate;
  final double avgScore;
  final int totalAttempts;
  final List<EnrollmentPoint> enrollmentTrend;

  const BookStats({
    required this.totalStudents,
    required this.completedStudents,
    required this.completionRate,
    required this.avgScore,
    required this.totalAttempts,
    required this.enrollmentTrend,
  });
}

class EnrollmentPoint {
  final DateTime date;
  final int count;
  const EnrollmentPoint({required this.date, required this.count});
}

class AdminStatsRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminStatsRepository');

  AdminStatsRepository(this._client, this._connectivity);

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

  Future<Either<Failure, List<StudentQuestionEntity>>> getRecentQuestions(
      String bookId) async {
    final net = _checkNetwork<List<StudentQuestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('student_questions')
          .select()
          .eq('book_id', bookId)
          .order('created_at', ascending: false)
          .limit(20);
      return Right((data as List)
          .map((e) =>
              StudentQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getRecentQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BookStats>> getBookStats(String bookId) async {
    final net = _checkNetwork<BookStats>();
    if (net != null) return net;
    try {
      // Total enrolled students
      final enrollData = await _client
          .from('enrollments')
          .select('id, enrolled_at')
          .eq('book_id', bookId)
          .limit(5000);
      final totalStudents = (enrollData as List).length;

      // Enrollment trend: group by date (last 30 days)
      final trend = _buildEnrollmentTrend(enrollData);

      // Certificates = students who completed the book
      final certData = await _client
          .from('certificates')
          .select('id')
          .eq('book_id', bookId)
          .limit(5000);
      final completedStudents = (certData as List).length;
      final completionRate = totalStudents == 0
          ? 0.0
          : completedStudents / totalStudents * 100;

      // Exam attempts & avg score
      final attemptData = await _client
          .from('final_exam_attempts')
          .select('score_percentage')
          .eq('book_id', bookId)
          .limit(5000);
      final attempts = (attemptData as List);
      final totalAttempts = attempts.length;
      final avgScore = attempts.isEmpty
          ? 0.0
          : attempts.fold<double>(
                  0,
                  (sum, e) =>
                      sum +
                      ((e as Map<String, dynamic>)['score_percentage'] as int)
                          .toDouble()) /
              attempts.length;

      return Right(BookStats(
        totalStudents: totalStudents,
        completedStudents: completedStudents,
        completionRate: completionRate,
        avgScore: avgScore,
        totalAttempts: totalAttempts,
        enrollmentTrend: trend,
      ));
    } on PostgrestException catch (e) {
      _log.warning('getBookStats: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  List<EnrollmentPoint> _buildEnrollmentTrend(List enrollData) {
    final counts = <DateTime, int>{};
    final now = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      counts[d] = 0;
    }
    for (final row in enrollData) {
      final at = DateTime.tryParse(
              (row as Map<String, dynamic>)['enrolled_at'] as String? ?? '') ??
          now;
      final day = DateTime(at.year, at.month, at.day);
      if (counts.containsKey(day)) counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => EnrollmentPoint(date: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
