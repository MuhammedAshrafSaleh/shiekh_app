// lib/features/notes/cubit/notes_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notes_repository.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesRepository _repo;
  String? _bookId;
  String? _lessonId;

  NotesCubit(this._repo) : super(NotesInitial());

  Future<void> loadBookNotes(String bookId) async {
    _bookId = bookId;
    _lessonId = null;
    emit(NotesLoading());
    final result = await _repo.getBookNotes(bookId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes)),
    );
  }

  Future<void> loadLessonNotes(String lessonId) async {
    _lessonId = lessonId;
    _bookId = null;
    emit(NotesLoading());
    final result = await _repo.getLessonNotes(lessonId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes)),
    );
  }

  Future<void> _reload() async {
    if (_lessonId != null) {
      await loadLessonNotes(_lessonId!);
    } else if (_bookId != null) {
      await loadBookNotes(_bookId!);
    }
  }

  Future<void> delete(String noteId) async {
    final result = await _repo.deleteNote(noteId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => _reload(),
    );
  }

  Future<void> refreshAfterEdit() async {
    await _reload();
  }
}
