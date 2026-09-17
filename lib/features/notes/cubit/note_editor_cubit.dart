// lib/features/notes/cubit/note_editor_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notes_repository.dart';
import 'note_editor_state.dart';

class NoteEditorCubit extends Cubit<NoteEditorState> {
  final NotesRepository _repo;

  NoteEditorCubit(this._repo) : super(NoteEditorInitial());

  Future<void> save({
    required String lessonId,
    required String bookId,
    required int positionSeconds,
    required String text,
  }) async {
    emit(NoteEditorSaving());
    final result = await _repo.addNote(
      lessonId: lessonId,
      bookId: bookId,
      positionSeconds: positionSeconds,
      text: text,
    );
    result.fold(
      (failure) => emit(NoteEditorError(failure.message)),
      (note) => emit(NoteEditorSuccess(note)),
    );
  }

  Future<void> updateText({
    required String noteId,
    required String text,
  }) async {
    emit(NoteEditorSaving());
    final result = await _repo.updateNoteText(noteId, text);
    result.fold(
      (failure) => emit(NoteEditorError(failure.message)),
      (note) => emit(NoteEditorSuccess(note)),
    );
  }
}
