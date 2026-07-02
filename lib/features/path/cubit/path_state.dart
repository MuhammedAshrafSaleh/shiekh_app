// lib/features/path/cubit/path_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/book_with_progress_entity.dart';

abstract class PathState extends Equatable {
  const PathState();

  @override
  List<Object?> get props => [];
}

class PathInitial extends PathState {
  const PathInitial();
}

class PathLoading extends PathState {
  const PathLoading();
}

class PathLoaded extends PathState {
  final List<BookWithProgressEntity> books;
  const PathLoaded(this.books);

  @override
  List<Object?> get props => [books];
}

class PathEmpty extends PathState {
  const PathEmpty();
}

class PathError extends PathState {
  final String message;
  const PathError(this.message);

  @override
  List<Object?> get props => [message];
}
