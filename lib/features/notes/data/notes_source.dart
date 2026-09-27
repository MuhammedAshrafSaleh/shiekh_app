// lib/features/notes/data/notes_source.dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../models/lesson_note_entity.dart';
import 'notes_repository.dart';
import 'suggestion_notes_repository.dart';

/// Abstracts WHERE a note lives (lesson vs suggestion) so `NotesCubit`,
/// `NoteEditorCubit`, and the notes widgets are reused unchanged across both.
/// Each implementation binds a repository to a concrete parent scope.
abstract class NotesSource {
  /// All notes for this scope, ordered by position_seconds ASC.
  Future<Either<Failure, List<LessonNoteEntity>>> fetch();

  /// Adds a note at [positionSeconds]. Not supported by read-only scopes.
  Future<Either<Failure, LessonNoteEntity>> add({
    required int positionSeconds,
    required String text,
  });

  Future<Either<Failure, LessonNoteEntity>> updateText(
    String noteId,
    String text,
  );

  Future<Either<Failure, Unit>> delete(String noteId);
}

/// Notes for a single lesson (the lesson player scope) — supports add.
class LessonNotesSource implements NotesSource {
  final NotesRepository _repo;
  final String lessonId;
  final String bookId;

  LessonNotesSource(this._repo, {required this.lessonId, required this.bookId});

  @override
  Future<Either<Failure, List<LessonNoteEntity>>> fetch() =>
      _repo.getLessonNotes(lessonId);

  @override
  Future<Either<Failure, LessonNoteEntity>> add({
    required int positionSeconds,
    required String text,
  }) => _repo.addNote(
    lessonId: lessonId,
    bookId: bookId,
    positionSeconds: positionSeconds,
    text: text,
  );

  @override
  Future<Either<Failure, LessonNoteEntity>> updateText(
    String noteId,
    String text,
  ) => _repo.updateNoteText(noteId, text);

  @override
  Future<Either<Failure, Unit>> delete(String noteId) =>
      _repo.deleteNote(noteId);
}

/// All notes across a whole book (the book "الملحوظات" tab + lecture list).
/// Read/edit/delete only — notes are never *added* from this scope.
class BookNotesSource implements NotesSource {
  final NotesRepository _repo;
  final String bookId;

  BookNotesSource(this._repo, {required this.bookId});

  @override
  Future<Either<Failure, List<LessonNoteEntity>>> fetch() =>
      _repo.getBookNotes(bookId);

  @override
  Future<Either<Failure, LessonNoteEntity>> add({
    required int positionSeconds,
    required String text,
  }) => throw UnsupportedError('Notes cannot be added from book scope');

  @override
  Future<Either<Failure, LessonNoteEntity>> updateText(
    String noteId,
    String text,
  ) => _repo.updateNoteText(noteId, text);

  @override
  Future<Either<Failure, Unit>> delete(String noteId) =>
      _repo.deleteNote(noteId);
}

/// Notes for a single suggestion video (the suggestion player scope).
class SuggestionNotesSource implements NotesSource {
  final SuggestionNotesRepository _repo;
  final String suggestionId;

  SuggestionNotesSource(this._repo, {required this.suggestionId});

  @override
  Future<Either<Failure, List<LessonNoteEntity>>> fetch() =>
      _repo.getSuggestionNotes(suggestionId);

  @override
  Future<Either<Failure, LessonNoteEntity>> add({
    required int positionSeconds,
    required String text,
  }) => _repo.addNote(
    suggestionId: suggestionId,
    positionSeconds: positionSeconds,
    text: text,
  );

  @override
  Future<Either<Failure, LessonNoteEntity>> updateText(
    String noteId,
    String text,
  ) => _repo.updateNoteText(noteId, text);

  @override
  Future<Either<Failure, Unit>> delete(String noteId) =>
      _repo.deleteNote(noteId);
}
