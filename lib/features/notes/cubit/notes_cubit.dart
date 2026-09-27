// lib/features/notes/cubit/notes_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notes_source.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesSource _source;

  NotesCubit(this._source) : super(NotesInitial());

  /// The bound source — widgets (e.g. NoteCard, the editor sheet) read this to
  /// add/edit against the same scope (lesson or suggestion) the cubit loaded.
  NotesSource get source => _source;

  Future<void> load() async {
    emit(NotesLoading());
    final result = await _source.fetch();
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes)),
    );
  }

  Future<void> delete(String noteId) async {
    final result = await _source.delete(noteId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => load(),
    );
  }

  Future<void> refreshAfterEdit() async {
    await load();
  }
}
