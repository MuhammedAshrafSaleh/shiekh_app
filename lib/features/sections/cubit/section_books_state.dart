// lib/features/sections/cubit/section_books_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/book_with_progress_entity.dart';

abstract class SectionBooksState extends Equatable {
  const SectionBooksState();

  @override
  List<Object?> get props => [];
}

class SectionBooksInitial extends SectionBooksState {
  const SectionBooksInitial();
}

class SectionBooksLoading extends SectionBooksState {
  const SectionBooksLoading();
}

class SectionBooksLoaded extends SectionBooksState {
  final List<BookWithProgressEntity> books;
  const SectionBooksLoaded(this.books);

  @override
  List<Object?> get props => [books];
}

class SectionBooksEmpty extends SectionBooksState {
  const SectionBooksEmpty();
}

class SectionBooksError extends SectionBooksState {
  const SectionBooksError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
