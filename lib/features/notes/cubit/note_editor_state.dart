// lib/features/notes/cubit/note_editor_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/lesson_note_entity.dart';

abstract class NoteEditorState extends Equatable {
  const NoteEditorState();

  @override
  List<Object?> get props => [];
}

class NoteEditorInitial extends NoteEditorState {}

class NoteEditorSaving extends NoteEditorState {}

class NoteEditorSuccess extends NoteEditorState {
  final LessonNoteEntity note;
  const NoteEditorSuccess(this.note);

  @override
  List<Object?> get props => [note];
}

class NoteEditorError extends NoteEditorState {
  final String message;
  const NoteEditorError(this.message);

  @override
  List<Object?> get props => [message];
}
