// lib/features/exam/data/exam_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/certificate_entity.dart';
import '../../../models/final_exam_attempt_entity.dart';
import '../../../models/final_exam_question_entity.dart';
import '../../../models/final_exam_settings_entity.dart';

class ExamMeta {
  final FinalExamSettingsEntity settings;
  final int questionCount;
  final int attemptsUsed;
  final List<FinalExamAttemptEntity> pastAttempts;

  const ExamMeta({
    required this.settings,
    required this.questionCount,
    required this.attemptsUsed,
    required this.pastAttempts,
  });
}

class ExamSubmitResult {
  final String attemptId;
  final int score;
  final int correct;
  final int total;
  final bool passed;
  final String gradeLabel;
  final bool certIssued;

  const ExamSubmitResult({
    required this.attemptId,
    required this.score,
    required this.correct,
    required this.total,
    required this.passed,
    required this.gradeLabel,
    required this.certIssued,
  });
}

class ExamReviewQuestion {
  final String id;
  final String questionText;
  final String choiceA;
  final String choiceB;
  final String choiceC;
  final String choiceD;
  final String correctChoice;
  final String? userAnswer;
  final bool isCorrect;

  const ExamReviewQuestion({
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

  factory ExamReviewQuestion.fromJson(Map<String, dynamic> json) {
    return ExamReviewQuestion(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      choiceA: json['choice_a'] as String,
      choiceB: json['choice_b'] as String,
      choiceC: json['choice_c'] as String,
      choiceD: json['choice_d'] as String,
      correctChoice: json['correct_choice'] as String,
      userAnswer: json['user_answer'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }
}

class ExamSession {
  final DateTime startedAt;
  final Map<String, String> answers;
  final int currentIndex;

  const ExamSession({
    required this.startedAt,
    required this.answers,
    required this.currentIndex,
  });

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'answers': answers,
    'currentIndex': currentIndex,
  };

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    return ExamSession(
      startedAt: DateTime.parse(json['startedAt'] as String),
      answers: Map<String, String>.from(json['answers'] as Map),
      currentIndex: json['currentIndex'] as int,
    );
  }
}

class ExamRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('ExamRepository');

  ExamRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, ExamMeta>> getExamMeta(String bookId) async {
    final networkError = _checkNetwork<ExamMeta>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final settingsResp = await _client
          .from('final_exam_settings')
          .select()
          .eq('book_id', bookId)
          .limit(1);

      final settingsList = settingsResp as List;
      if (settingsList.isEmpty) {
        return Left(ServerFailure('الاختبار غير متاح لهذا الكتاب'));
      }
      final settings = FinalExamSettingsEntity.fromJson(
        settingsList.first as Map<String, dynamic>,
      );

      final countResp = await _client
          .from('final_exam_questions_student')
          .select('id')
          .eq('book_id', bookId);

      final questionCount = (countResp as List).length;

      final attemptsResp = await _client
          .from('final_exam_attempts')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('attempt_number', ascending: true)
          .limit(10);

      final attempts = (attemptsResp as List)
          .map(
            (e) => FinalExamAttemptEntity.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      return Right(
        ExamMeta(
          settings: settings,
          questionCount: questionCount,
          attemptsUsed: attempts.length,
          pastAttempts: attempts,
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('getExamMeta: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// True when the current user has an enrollment row for [bookId]. A guest is
  /// never enrolled, so this single check covers both the guest and the
  /// registered-not-enrolled cases behind the exam-page enrollment gate.
  Future<Either<Failure, bool>> isEnrolled(String bookId) async {
    final networkError = _checkNetwork<bool>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final resp = await _client
          .from('enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .limit(1);

      return Right((resp as List).isNotEmpty);
    } on PostgrestException catch (e) {
      _log.warning('isEnrolled: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // CC-18: uses final_exam_questions_student view (no correct_choice)
  Future<Either<Failure, List<FinalExamQuestionEntity>>> getQuestions(
    String bookId,
  ) async {
    final networkError = _checkNetwork<List<FinalExamQuestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('final_exam_questions_student')
          .select()
          .eq('book_id', bookId)
          .order('order_index', ascending: true)
          .limit(200);

      final questions = (response as List)
          .map(
            (e) => FinalExamQuestionEntity.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // Single RPC call — never do client-side grading (CC-18)
  Future<Either<Failure, ExamSubmitResult>> submitExam(
    String bookId,
    Map<String, String> answers,
    DateTime startedAt,
  ) async {
    final networkError = _checkNetwork<ExamSubmitResult>();
    if (networkError != null) return networkError;

    try {
      final response = await _client.rpc(
        'submit_final_exam',
        params: {
          'p_book_id': bookId,
          'p_answers': answers,
          'p_started_at': startedAt.toIso8601String(),
        },
      );

      final data = response as Map<String, dynamic>;
      return Right(
        ExamSubmitResult(
          attemptId: data['attempt_id'] as String,
          score: data['score'] as int,
          correct: data['correct'] as int,
          total: data['total'] as int,
          passed: data['passed'] as bool,
          gradeLabel: data['grade_label'] as String? ?? '',
          certIssued: data['cert_issued'] as bool? ?? false,
        ),
      );
    } on PostgrestException catch (e) {
      _log.warning('submitExam: ${e.message}');
      final msg = switch (e.code) {
        'P0001' => 'يجب التسجيل في الكتاب أولاً',
        'P0002' => 'الاختبار غير منشور بعد',
        'P0003' => 'لقد استنفدت جميع محاولاتك',
        'P0004' => 'لا توجد أسئلة في هذا الاختبار',
        _ => 'حدث خطأ أثناء تسليم الاختبار',
      };
      return Left(ServerFailure(msg));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<ExamReviewQuestion>>> getExamReview(
    String bookId,
    String attemptId,
  ) async {
    final networkError = _checkNetwork<List<ExamReviewQuestion>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client.rpc(
        'get_final_exam_review',
        params: {'p_book_id': bookId, 'p_attempt_id': attemptId},
      );

      final list = response as List? ?? [];
      final questions = list
          .map((e) => ExamReviewQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(questions);
    } on PostgrestException catch (e) {
      _log.warning('getExamReview: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<CertificateEntity>>> getCertificates() async {
    final networkError = _checkNetwork<List<CertificateEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('certificates')
          .select()
          .eq('user_id', userId)
          .order('issued_at', ascending: false)
          .limit(50);

      final certs = (response as List)
          .map((e) => CertificateEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(certs);
    } on PostgrestException catch (e) {
      _log.warning('getCertificates: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  // Session persistence (CC-11)
  Future<ExamSession?> loadSession(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('exam_${bookId}_session');
      if (raw == null) return null;
      return ExamSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(String bookId, ExamSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'exam_${bookId}_session',
      jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('exam_${bookId}_session');
  }
}
