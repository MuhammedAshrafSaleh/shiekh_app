// lib/features/admin/levels/cubit/admin_level_book_picker_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/assignable_book_entity.dart';

abstract class AdminLevelBookPickerState extends Equatable {
  const AdminLevelBookPickerState();
  @override
  List<Object?> get props => [];
}

class AdminLevelBookPickerInitial extends AdminLevelBookPickerState {}

class AdminLevelBookPickerLoading extends AdminLevelBookPickerState {}

class AdminLevelBookPickerLoaded extends AdminLevelBookPickerState {
  final List<AssignableBookEntity> books;
  const AdminLevelBookPickerLoaded(this.books);
  @override
  List<Object?> get props => [books];
}

class AdminLevelBookPickerError extends AdminLevelBookPickerState {
  final String message;
  const AdminLevelBookPickerError(this.message);
  @override
  List<Object?> get props => [message];
}
