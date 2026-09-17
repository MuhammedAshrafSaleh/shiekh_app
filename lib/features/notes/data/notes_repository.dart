// lib/features/notes/data/notes_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/lesson_note_entity.dart';

class NotesRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('NotesRepository');

  NotesRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<LessonNoteEntity>>> getBookNotes(
    String bookId,
  ) async {
    final networkError = _checkNetwork<List<LessonNoteEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('lesson_notes')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('position_seconds', ascending: true)
          .limit(500);

      final notes = (response as List)
          .cast<Map<String, dynamic>>()
          .map(LessonNoteEntity.fromJson)
          .toList();

      return Right(notes);
    } on PostgrestException catch (e) {
      _log.warning('getBookNotes: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonNoteEntity>> addNote({
    required String lessonId,
    required String bookId,
    required int positionSeconds,
    required String text,
  }) async {
    final networkError = _checkNetwork<LessonNoteEntity>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('lesson_notes')
          .insert({
            'user_id': userId,
            'lesson_id': lessonId,
            'book_id': bookId,
            'position_seconds': positionSeconds,
            'note_text': text,
          })
          .select()
          .single();

      return Right(LessonNoteEntity.fromJson(response));
    } on PostgrestException catch (e) {
      _log.warning('addNote: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LessonNoteEntity>> updateNoteText(
    String noteId,
    String text,
  ) async {
    final networkError = _checkNetwork<LessonNoteEntity>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('lesson_notes')
          .update({'note_text': text})
          .eq('id', noteId)
          .eq('user_id', userId)
          .select()
          .single();

      return Right(LessonNoteEntity.fromJson(response));
    } on PostgrestException catch (e) {
      _log.warning('updateNoteText: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteNote(String noteId) async {
    final networkError = _checkNetwork<Unit>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      await _client
          .from('lesson_notes')
          .delete()
          .eq('id', noteId)
          .eq('user_id', userId);

      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteNote: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
