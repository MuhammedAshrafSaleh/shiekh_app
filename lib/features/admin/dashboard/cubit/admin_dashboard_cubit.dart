// lib/features/admin/dashboard/cubit/admin_dashboard_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_dashboard_repository.dart';
import 'admin_dashboard_state.dart';

class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  final AdminDashboardRepository _repo;

  AdminDashboardCubit(this._repo) : super(AdminDashboardInitial());

  Future<void> load() async {
    emit(AdminDashboardLoading());
    final statsResult = await _repo.getStats();
    final booksResult = await _repo.getAllBooks();

    final failure = statsResult.fold((f) => f, (_) => null) ??
        booksResult.fold((f) => f, (_) => null);

    if (failure != null) {
      emit(AdminDashboardError(failure.message));
      return;
    }

    emit(AdminDashboardLoaded(
      stats: statsResult.getOrElse(() => const AdminStats(
            totalBooks: 0,
            totalStudents: 0,
            totalLessons: 0,
            pendingQa: 0,
          )),
      books: booksResult.getOrElse(() => []),
    ));
  }

  Future<void> deleteBook(String bookId) async {
    final result = await _repo.deleteBook(bookId);
    result.fold(
      (failure) => emit(AdminDashboardError(failure.message)),
      (_) => load(),
    );
  }
}
