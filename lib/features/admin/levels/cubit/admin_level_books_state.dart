// lib/features/admin/levels/cubit/admin_level_books_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/book_entity.dart';

abstract class AdminLevelBooksState extends Equatable {
  const AdminLevelBooksState();
  @override
  List<Object?> get props => [];
}

class AdminLevelBooksInitial extends AdminLevelBooksState {}

class AdminLevelBooksLoading extends AdminLevelBooksState {}

/// Books in the level. Carries one-shot feedback for add / remove / reorder so
/// those mutations never blank the list (mirrors AdminLevelsLoaded).
class AdminLevelBooksLoaded extends AdminLevelBooksState {
  final List<BookEntity> books;
  final String? transientSuccess;
  final int successNonce;
  final String? transientError;
  final int errorNonce;

  const AdminLevelBooksLoaded(
    this.books, {
    this.transientSuccess,
    this.successNonce = 0,
    this.transientError,
    this.errorNonce = 0,
  });

  @override
  List<Object?> get props => [
    books,
    transientSuccess,
    successNonce,
    transientError,
    errorNonce,
  ];
}

class AdminLevelBooksError extends AdminLevelBooksState {
  final String message;
  const AdminLevelBooksError(this.message);
  @override
  List<Object?> get props => [message];
}
