// lib/features/admin/shared/data/question_bank_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/bank_lesson_summary_entity.dart';

/// Read-only access to the question bank for the shared import drill-down.
/// Used by BOTH the book-exam and lesson-quiz import scopes; the scope-specific
/// insert (copy) stays in each feature's own repository.
///
/// The bank contains **originals only**: every query filters
/// `ai_review_status = 'approved'` AND `source_question_id IS NULL`, so an
/// imported copy never re-appears and can't be re-imported.
class QuestionBankRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('QuestionBankRepository');

  QuestionBankRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// Step 1: the book's lessons that have importable questions, each with its
  /// approved-original count. Backed by the `bank_lesson_summaries` RPC.
  Future<Either<Failure, List<BankLessonSummaryEntity>>> getBankLessonSummaries(
    String bookId,
  ) async {
    final net = _checkNetwork<List<BankLessonSummaryEntity>>();
    if (net != null) return net;
    try {
      final data = await _client.rpc(
        'bank_lesson_summaries',
        params: {'p_book_id': bookId},
      );
      return Right(
        (data as List)
            .map(
              (e) =>
                  BankLessonSummaryEntity.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getBankLessonSummaries: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Step 2: one lesson's importable questions (approved originals), loaded
  /// lazily when the admin drills into that lesson. Bounded by a generous
  /// `.limit` — a single lesson's question set is inherently small.
  Future<Either<Failure, List<AdminQuizQuestionEntity>>> getLessonBankQuestions(
    String lessonId,
  ) async {
    final net = _checkNetwork<List<AdminQuizQuestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('lesson_quiz_questions')
          .select()
          .eq('lesson_id', lessonId)
          .eq('ai_review_status', 'approved')
          .isFilter('source_question_id', null)
          .order('order_index', ascending: true)
          .limit(200); // safety bound; one lesson's set is inherently small
      return Right(
        (data as List)
            .map(
              (e) =>
                  AdminQuizQuestionEntity.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getLessonBankQuestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
