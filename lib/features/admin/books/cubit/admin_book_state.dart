// lib/features/admin/books/cubit/admin_book_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/book_entity.dart';
import '../../../../models/section_entity.dart';

abstract class AdminBookState extends Equatable {
  const AdminBookState();
  @override
  List<Object?> get props => [];
}

class AdminBookInitial extends AdminBookState {}

class AdminBookLoading extends AdminBookState {}

class AdminBookFormReady extends AdminBookState {
  final List<SectionEntity> sections;
  final BookEntity? existing;
  final int featuredCount;

  const AdminBookFormReady({
    required this.sections,
    this.existing,
    required this.featuredCount,
  });

  @override
  List<Object?> get props => [sections, existing, featuredCount];
}

class AdminBookSaving extends AdminBookState {}

class AdminBookSaveSuccess extends AdminBookState {
  final BookEntity book;
  const AdminBookSaveSuccess(this.book);
  @override
  List<Object?> get props => [book];
}

class AdminBookError extends AdminBookState {
  final String message;
  const AdminBookError(this.message);
  @override
  List<Object?> get props => [message];
}
