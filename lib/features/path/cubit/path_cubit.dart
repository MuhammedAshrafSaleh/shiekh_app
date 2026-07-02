// lib/features/path/cubit/path_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/path_repository.dart';
import 'path_state.dart';

class PathCubit extends Cubit<PathState> {
  final PathRepository _repository;

  PathCubit(this._repository) : super(const PathInitial());

  Future<void> loadPath() async {
    emit(const PathLoading());
    final result = await _repository.getEnrolledBooks();
    if (isClosed) return;
    result.fold(
      (failure) => emit(PathError(failure.message)),
      (books) =>
          books.isEmpty ? emit(const PathEmpty()) : emit(PathLoaded(books)),
    );
  }
}
