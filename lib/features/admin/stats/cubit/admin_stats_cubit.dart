// lib/features/admin/stats/cubit/admin_stats_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_stats_repository.dart';
import 'admin_stats_state.dart';

class AdminStatsCubit extends Cubit<AdminStatsState> {
  final AdminStatsRepository _repo;

  AdminStatsCubit(this._repo) : super(AdminStatsInitial());

  Future<void> load(String bookId) async {
    emit(AdminStatsLoading());
    final lessonsResult = await _repo.getLessons(bookId);
    await lessonsResult.fold(
      (f) async => emit(AdminStatsError(f.message)),
      (lessons) async {
        final statsResult = await _repo.getBookStats(bookId);
        await statsResult.fold(
          (f) async => emit(AdminStatsError(f.message)),
          (stats) async {
            final qResult = await _repo.getRecentQuestions(bookId);
            qResult.fold(
              (f) => emit(AdminStatsError(f.message)),
              (questions) => emit(AdminStatsLoaded(
                lessons: lessons,
                stats: stats,
                recentQuestions: questions,
              )),
            );
          },
        );
      },
    );
  }
}
