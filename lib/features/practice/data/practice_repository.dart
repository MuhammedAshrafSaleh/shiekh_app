// lib/features/practice/data/practice_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../models/practice_attempt_summary_entity.dart';
import '../../../models/practice_eligible_lesson_entity.dart';
import '../../../models/practice_lecture_breakdown.dart';
import '../../../models/practice_review_question.dart';
import '../../../models/quiz_question_entity.dart';
import '../../notifications/cubit/connectivity_cubit.dart';

/// Result of grading a freshly submitted practice attempt.
class PracticeSubmitResult {
  final String attemptId;
  final int score;
  final int correct;
  final int total;
  final List<PracticeLectureBreakdown> breakdown;
  final List<PracticeReviewQuestion> review;

  const PracticeSubmitResult({
    required this.attemptId,
    required this.score,
    required this.correct,
    required this.total,
    required this.breakdown,
    required this.review,
  });
}

/// Full detail of a past practice attempt, loaded on tap from history.
class PracticeAttemptReview {
  final String attemptId;
  final int score;
  final int correct;
  final int total;
  final List<PracticeLectureBreakdown> breakdown;
  final int durationSeconds;
  final int? timeLimitMinutes;
  final DateTime createdAt;
  final List<PracticeReviewQuestion> review;

  const PracticeAttemptReview({
    required this.attemptId,
    required this.score,
    required this.correct,
    required this.total,
    required this.breakdown,
    required this.durationSeconds,
    required this.timeLimitMinutes,
    required this.createdAt,
    required this.review,
  });
}

/// Data layer for the student "Practice Exams" (اختبر نفسك) feature.
///
/// Reads the question pool from the CC-18-safe `lesson_quiz_questions_student`
/// view (no `correct_choice`); all grading happens server-side in the
/// `submit_practice_attempt` RPC. Writes touch only `practice_attempts`.
class PracticeRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('PracticeRepository');

  PracticeRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// Lessons the student may practice (official quiz submitted + approved
  /// questions remaining). Ordered server-side by book then lesson order.
  Future<Either<Failure, List<PracticeEligibleLessonEntity>>>
  getEligibleLessons() async {
    final networkError = _checkNetwork<List<PracticeEligibleLessonEntity>>();
    if (networkError != null) return networkError;

    if (_client.auth.currentUser == null) {
      return Left(AuthFailure('يجب تسجيل الدخول أولاً'));
    }

    try {
      final response = await _client.rpc('get_practice_eligible_lessons');
      final lessons = (response as List)
          .map(
            (e) => PracticeEligibleLessonEntity.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
      return Right(lessons);
    } on PostgrestException catch (e) {
      _log.warning('getEligibleLessons: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Fetches the (answer-free) question pool for the selected [lessonIds] from
  /// the student view. The cubit groups these by lesson for the pure
  /// distribution function and keeps the full objects for display.
  Future<Either<Failure, List<QuizQuestionEntity>>> getQuestionPool(
    List<String> lessonIds,
  ) async {
    final networkError = _checkNetwork<List<QuizQuestionEntity>>();
    if (networkError != null) return networkError;

    if (lessonIds.isEmpty) return const Right([]);

    try {
      final response = await _client
          .from('lesson_quiz_questions_student')
          .select()
          .inFilter('lesson_id', lessonIds)
          .limit(5000);

      final questions = (response as List)
          .map((e) => QuizQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getQuestionPool: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Submits a completed practice exam for server-side grading. [answers] maps
  /// questionId → chosen letter ('a'..'d'); unanswered questions are omitted.
  Future<Either<Failure, PracticeSubmitResult>> submitAttempt({
    required List<String> questionOrder,
    required Map<String, String> answers,
    required int durationSeconds,
    int? timeLimitMinutes,
  }) async {
    final networkError = _checkNetwork<PracticeSubmitResult>();
    if (networkError != null) return networkError;

    if (_client.auth.currentUser == null) {
      return Left(AuthFailure('يجب تسجيل الدخول أولاً'));
    }

    try {
      final response = await _client.rpc(
        'submit_practice_attempt',
        params: {
          'p_question_order': questionOrder,
          'p_answers': answers,
          'p_duration_seconds': durationSeconds,
          'p_time_limit_minutes': timeLimitMinutes,
        },
      );

      final data = response as Map<String, dynamic>;
      return Right(
        PracticeSubmitResult(
          attemptId: data['attempt_id'] as String,
          score: (data['score'] as num).toInt(),
          correct: (data['correct'] as num).toInt(),
          total: (data['total'] as num).toInt(),
          breakdown: _parseBreakdown(data['breakdown']),
          review: _parseReview(data['review']),
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('submitAttempt: ${e.message}');
      return Left(_mapSubmitError(e));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// The student's last (up to 10) submitted attempts — summary columns only.
  /// RLS restricts rows to the caller.
  Future<Either<Failure, List<PracticeAttemptSummaryEntity>>>
  getHistory() async {
    final networkError = _checkNetwork<List<PracticeAttemptSummaryEntity>>();
    if (networkError != null) return networkError;

    if (_client.auth.currentUser == null) {
      return Left(AuthFailure('يجب تسجيل الدخول أولاً'));
    }

    try {
      // Deliberately omits the heavy `answers`/`question_order` columns; detail
      // is loaded on tap via get_practice_attempt_review.
      final response = await _client
          .from('practice_attempts')
          .select(
            'id, score_percentage, correct_count, total_count, '
            'lesson_ids, breakdown, duration_seconds, time_limit_minutes, '
            'created_at',
          )
          .order('created_at', ascending: false)
          .limit(10);

      final attempts = (response as List)
          .map(
            (e) => PracticeAttemptSummaryEntity.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
      return Right(attempts);
    } on PostgrestException catch (e) {
      _log.warning('getHistory: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Reconstructs the full review of a past attempt (deleted questions appear
  /// as tombstones). Owner-only, enforced server-side.
  Future<Either<Failure, PracticeAttemptReview>> getAttemptReview(
    String attemptId,
  ) async {
    final networkError = _checkNetwork<PracticeAttemptReview>();
    if (networkError != null) return networkError;

    if (_client.auth.currentUser == null) {
      return Left(AuthFailure('يجب تسجيل الدخول أولاً'));
    }

    try {
      final response = await _client.rpc(
        'get_practice_attempt_review',
        params: {'p_attempt_id': attemptId},
      );

      final data = response as Map<String, dynamic>;
      return Right(
        PracticeAttemptReview(
          attemptId: data['attempt_id'] as String,
          score: (data['score'] as num).toInt(),
          correct: (data['correct'] as num).toInt(),
          total: (data['total'] as num).toInt(),
          breakdown: _parseBreakdown(data['breakdown']),
          durationSeconds: (data['duration_seconds'] as num).toInt(),
          timeLimitMinutes: (data['time_limit_minutes'] as num?)?.toInt(),
          createdAt: DateTime.parse(data['created_at'] as String),
          review: _parseReview(data['review']),
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('getAttemptReview: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // --- helpers -------------------------------------------------------------

  List<PracticeLectureBreakdown> _parseBreakdown(dynamic raw) {
    return (raw as List? ?? const [])
        .map(
          (e) => PracticeLectureBreakdown.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  List<PracticeReviewQuestion> _parseReview(dynamic raw) {
    return (raw as List? ?? const [])
        .map((e) => PracticeReviewQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Failure _mapSubmitError(PostgrestException e) {
    final msg = e.message;
    if (msg.contains('NO_VALID_QUESTIONS')) {
      return ValidationFailure('تعذّر إنشاء الاختبار، اختر محاضرات أخرى');
    }
    if (msg.contains('TAMPERING')) {
      return PermissionFailure('حدث خطأ في بيانات الاختبار');
    }
    if (msg.contains('INVALID_COUNT') ||
        msg.contains('DUPLICATE_QUESTIONS') ||
        msg.contains('INVALID_ANSWER') ||
        msg.contains('INVALID_DURATION')) {
      return ValidationFailure('بيانات الاختبار غير صالحة');
    }
    return ServerFailure('تعذّر حفظ نتيجة الاختبار، حاول مرة أخرى');
  }
}
