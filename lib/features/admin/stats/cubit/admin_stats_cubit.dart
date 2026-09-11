// lib/features/admin/stats/cubit/admin_stats_cubit.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../data/admin_stats_repository.dart';
import 'admin_stats_state.dart';

class AdminStatsCubit extends Cubit<AdminStatsState> {
  final AdminStatsRepository _repo;
  String? _bookId;

  AdminStatsCubit(this._repo) : super(AdminStatsInitial());

  Future<void> load(String bookId) async {
    _bookId = bookId;
    emit(AdminStatsLoading());
    final lessonsResult = await _repo.getLessons(bookId);
    await lessonsResult.fold((f) async => emit(AdminStatsError(f.message)), (
      lessons,
    ) async {
      final statsResult = await _repo.getBookStats(bookId);
      await statsResult.fold((f) async => emit(AdminStatsError(f.message)), (
        stats,
      ) async {
        final qResult = await _repo.getBookQuestions(bookId);
        qResult.fold(
          (f) => emit(AdminStatsError(f.message)),
          (questions) => emit(
            AdminStatsLoaded(
              lessons: lessons,
              stats: stats,
              questions: questions,
            ),
          ),
        );
      });
    });
  }

  Future<bool> answerQuestion({
    required String questionId,
    required String answerText,
  }) => _mutate(
    () => _repo.answerQuestion(questionId: questionId, answerText: answerText),
  );

  Future<bool> editAnswer({
    required String questionId,
    required String answerText,
  }) => _mutate(
    () => _repo.editAnswer(questionId: questionId, answerText: answerText),
  );

  Future<bool> deleteQuestion(String questionId) =>
      _mutate(() => _repo.deleteQuestion(questionId));

  Future<bool> clearBookQuestions() {
    final bookId = _bookId;
    if (bookId == null) return Future.value(false);
    return _mutate(() => _repo.clearBookQuestions(bookId));
  }

  /// Runs a repository mutation, reloads on success, emits error on failure.
  Future<bool> _mutate(
    Future<Either<Failure, Object?>> Function() action,
  ) async {
    final result = await action();
    return result.fold(
      (f) {
        emit(AdminStatsError(f.message));
        return false;
      },
      (_) {
        final bookId = _bookId;
        if (bookId != null) load(bookId);
        return true;
      },
    );
  }
}
