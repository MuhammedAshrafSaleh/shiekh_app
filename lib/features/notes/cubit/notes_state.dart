// lib/features/notes/cubit/notes_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/lesson_note_entity.dart';

abstract class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

class NotesInitial extends NotesState {}

class NotesLoading extends NotesState {}

class NotesLoaded extends NotesState {
  final List<LessonNoteEntity> notes;
  const NotesLoaded(this.notes);

  @override
  List<Object?> get props => [notes];
}

class NotesError extends NotesState {
  final String message;
  const NotesError(this.message);

  @override
  List<Object?> get props => [message];
}
