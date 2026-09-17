// lib/features/notes/cubit/notes_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notes_repository.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesRepository _repo;
  String? _bookId;

  NotesCubit(this._repo) : super(NotesInitial());

  Future<void> loadBookNotes(String bookId) async {
    _bookId = bookId;
    emit(NotesLoading());
    final result = await _repo.getBookNotes(bookId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes)),
    );
  }

  Future<void> delete(String noteId) async {
    final bookId = _bookId;
    if (bookId == null) return;
    final result = await _repo.deleteNote(noteId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => loadBookNotes(bookId),
    );
  }

  Future<void> refreshAfterEdit() async {
    final bookId = _bookId;
    if (bookId == null) return;
    await loadBookNotes(bookId);
  }
}
