// lib/features/lesson/data/lesson_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/lesson_entity.dart';
import '../../../models/lesson_progress_entity.dart';
import '../../../models/lesson_quiz_attempt_entity.dart';
import '../../../models/quiz_question_entity.dart';

/// The medium a resume position belongs to. Video and audio positions are stored
/// in separate columns so one tab's save never overwrites the other's.
enum MediaType { video, audio }

class QuizGradeResult {
  final int correct;
  final int total;
  final int percentage;
  final int attemptsUsed;

  const QuizGradeResult({
    required this.correct,
    required this.total,
    required this.percentage,
    required this.attemptsUsed,
  });
}

class LessonQuizMeta {
  /// Entitlement-INDEPENDENT presence flag (from lessons_public.has_quiz): true
  /// iff the lesson actually has a quiz, regardless of whether this viewer may
  /// see its content. Drives quiz-tab VISIBILITY.
  final bool hasQuiz;

  /// Entitled question count (from the student view). 0 for guests — used for
  /// the enrolled quiz flow, NOT for tab visibility.
  final int questionCount;
  final int attemptsUsed;
  final List<LessonQuizAttemptEntity> pastAttempts;

  const LessonQuizMeta({
    required this.hasQuiz,
    required this.questionCount,
    required this.attemptsUsed,
    required this.pastAttempts,
  });
}

class QuizReviewQuestion {
  final String id;
  final String questionText;
  final String choiceA;
  final String choiceB;
  final String choiceC;
  final String choiceD;
  final String correctChoice;
  final String? userAnswer;
  final bool isCorrect;

  const QuizReviewQuestion({
    required this.id,
    required this.questionText,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.choiceD,
    required this.correctChoice,
    required this.userAnswer,
    required this.isCorrect,
  });

  factory QuizReviewQuestion.fromJson(Map<String, dynamic> json) {
    return QuizReviewQuestion(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      choiceA: json['choice_a'] as String,
      choiceB: json['choice_b'] as String,
      choiceC: json['choice_c'] as String,
      choiceD: json['choice_d'] as String,
      correctChoice: json['correct_choice'] as String,
      userAnswer: json['user_answer'] as String?,
      isCorrect: json['is_correct'] as bool,
    );
  }

  String choiceText(String key) => switch (key) {
    'a' => choiceA,
    'b' => choiceB,
    'c' => choiceC,
    'd' => choiceD,
    _ => '',
  };
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
      // Embed the lesson's PDFs in one round-trip (migration 0012). RLS on
      // lesson_pdfs already filters the child rows to entitled/published content.
      final response = await _client
          .from('lessons')
          .select('*, lesson_pdfs(*)')
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

  /// Whether the current session is enrolled in [bookId]. Guests and unenrolled
  /// users resolve to false (enrollments RLS returns them 0 rows). Used to decide
  /// whether the quiz tab shows real content or a gate.
  Future<Either<Failure, bool>> isEnrolledInBook(String bookId) async {
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
      _log.warning('isEnrolledInBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonProgressEntity?>> getLessonProgress(
    String lessonId,
  ) async {
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
        LessonProgressEntity.fromJson(rows.first as Map<String, dynamic>),
      );
    } on PostgrestException catch (e) {
      _log.warning('getLessonProgress: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-21: upsert on (user_id, lesson_id). Writes only the column for [mediaType]
  // so the other medium's saved resume position is left untouched.
  Future<Either<Failure, Unit>> saveProgress({
    required String lessonId,
    required MediaType mediaType,
    required int positionSeconds,
    required bool completed,
  }) async {
    final networkError = _checkNetwork<Unit>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final now = DateTime.now().toIso8601String();
      final column = mediaType == MediaType.video
          ? 'video_position_seconds'
          : 'audio_position_seconds';
      await _client.from('lesson_progress').upsert({
        'user_id': userId,
        'lesson_id': lessonId,
        'completed': completed,
        column: positionSeconds,
        if (completed) 'completed_at': now,
        'updated_at': now,
      }, onConflict: 'user_id,lesson_id');

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
    String lessonId,
  ) async {
    final networkError = _checkNetwork<List<QuizQuestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('lesson_quiz_questions_student')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_index', ascending: true)
          .limit(50);

      final questions = (response as List)
          .map((e) => QuizQuestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getQuizQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonQuizMeta>> getQuizMeta(String lessonId) async {
    final networkError = _checkNetwork<LessonQuizMeta>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;

      // Entitlement-independent presence flag (lessons_public runs as owner).
      final metaRow = await _client
          .from('lessons_public')
          .select('has_quiz')
          .eq('id', lessonId)
          .maybeSingle();
      final hasQuiz = (metaRow?['has_quiz'] as bool?) ?? false;

      // Entitled question count (0 for guests via the student view's is_guest guard).
      final questionsResponse = await _client
          .from('lesson_quiz_questions_student')
          .select('id')
          .eq('lesson_id', lessonId)
          .limit(50);

      final questionCount = (questionsResponse as List).length;

      List<LessonQuizAttemptEntity> pastAttempts = [];
      if (userId != null) {
        final attemptsResponse = await _client
            .from('lesson_quiz_attempts')
            .select()
            .eq('user_id', userId)
            .eq('lesson_id', lessonId)
            .order('attempt_number', ascending: true)
            .limit(2);

        pastAttempts = (attemptsResponse as List)
            .map(
              (e) =>
                  LessonQuizAttemptEntity.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      return Right(
        LessonQuizMeta(
          hasQuiz: hasQuiz,
          questionCount: questionCount,
          attemptsUsed: pastAttempts.length,
          pastAttempts: pastAttempts,
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('getQuizMeta: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, QuizGradeResult>> submitQuiz(
    String lessonId,
    Map<String, String> answers,
  ) async {
    final networkError = _checkNetwork<QuizGradeResult>();
    if (networkError != null) return networkError;

    try {
      final response = await _client.rpc(
        'submit_lesson_quiz',
        params: {'p_lesson_id': lessonId, 'p_answers': answers},
      );

      final data = response as Map<String, dynamic>;
      return Right(
        QuizGradeResult(
          correct: data['correct'] as int,
          total: data['total'] as int,
          percentage: data['percentage'] as int,
          attemptsUsed: data['attempts_used'] as int,
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('submitQuiz: ${e.message}');
      if (e.message.contains('attempts_exhausted')) {
        return Left(const AttemptsExhaustedFailure());
      }
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<QuizReviewQuestion>>> getQuizReview(
    String lessonId, {
    int? attemptNumber,
  }) async {
    final networkError = _checkNetwork<List<QuizReviewQuestion>>();
    if (networkError != null) return networkError;

    try {
      final params = <String, dynamic>{'p_lesson_id': lessonId};
      if (attemptNumber != null) params['p_attempt_number'] = attemptNumber;
      final response = await _client.rpc(
        'get_lesson_quiz_review',
        params: params,
      );

      final data = response as Map<String, dynamic>;
      final questions = (data['questions'] as List)
          .map((e) => QuizReviewQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getQuizReview: ${e.message}');
      if (e.message.contains('no_attempt_found')) {
        return Left(ServerFailure('لا توجد محاولة مسجلة'));
      }
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // Server-side grading (CC-18) — admin preview only, no attempt stored
  Future<Either<Failure, QuizGradeResult>> gradeQuiz(
    String lessonId,
    Map<String, String> answers,
  ) async {
    final networkError = _checkNetwork<QuizGradeResult>();
    if (networkError != null) return networkError;

    try {
      final response = await _client.rpc(
        'grade_lesson_quiz',
        params: {'p_lesson_id': lessonId, 'p_answers': answers},
      );

      final data = response as Map<String, dynamic>;
      return Right(
        QuizGradeResult(
          correct: data['correct'] as int,
          total: data['total'] as int,
          percentage: data['percentage'] as int,
          attemptsUsed: 0,
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('gradeQuiz: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonEntity?>> getNextLesson(
    String bookId,
    int currentOrderIndex,
  ) async {
    final networkError = _checkNetwork<LessonEntity?>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('lessons')
          .select()
          .eq('book_id', bookId)
          .eq('status', 'published')
          .gt('order_index', currentOrderIndex)
          .order('order_index', ascending: true)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(null);
      return Right(LessonEntity.fromJson(rows.first as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      _log.warning('getNextLesson: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
