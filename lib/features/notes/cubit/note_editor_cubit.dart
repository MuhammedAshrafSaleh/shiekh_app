// lib/features/notes/cubit/note_editor_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notes_source.dart';
import 'note_editor_state.dart';

class NoteEditorCubit extends Cubit<NoteEditorState> {
  final NotesSource _source;

  NoteEditorCubit(this._source) : super(NoteEditorInitial());

  Future<void> save({
    required int positionSeconds,
    required String text,
  }) async {
    emit(NoteEditorSaving());
    final result = await _source.add(
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
    final result = await _source.updateText(noteId, text);
    result.fold(
      (failure) => emit(NoteEditorError(failure.message)),
      (note) => emit(NoteEditorSuccess(note)),
    );
  }
}
