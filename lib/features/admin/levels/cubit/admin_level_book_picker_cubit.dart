// lib/features/admin/levels/cubit/admin_level_book_picker_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_level_repository.dart';
import 'admin_level_book_picker_state.dart';

/// Lists the books that can be added to a level (free books + books in other
/// levels, for MOVE). The picker only loads; the actual assign/move is done by
/// [AdminLevelBooksCubit.addBook] after the page pops the chosen book id.
class AdminLevelBookPickerCubit extends Cubit<AdminLevelBookPickerState> {
  final AdminLevelRepository _repo;
  final String levelId;

  AdminLevelBookPickerCubit(this._repo, this.levelId)
    : super(AdminLevelBookPickerInitial());

  Future<void> load() async {
    emit(AdminLevelBookPickerLoading());
    final result = await _repo.getAssignableBooks(levelId);
    result.fold(
      (f) => emit(AdminLevelBookPickerError(f.message)),
      (books) => emit(AdminLevelBookPickerLoaded(books)),
    );
  }
}
