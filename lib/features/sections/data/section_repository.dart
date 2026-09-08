// lib/features/sections/data/section_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/book_entity.dart';
import '../../../models/book_with_progress_entity.dart';
import '../../../models/section_entity.dart';

class SectionRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('SectionRepository');

  SectionRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<SectionEntity>>> getSections() async {
    final networkError = _checkNetwork<List<SectionEntity>>();
    if (networkError != null) return networkError;

    try {
      final sectionsRaw = await _client.from('sections').select().limit(50);

      final booksRaw = await _client
          .from('books')
          .select('section_id')
          .eq('status', 'published')
          .limit(500);

      final Map<String, int> countBySection = {};
      for (final row in (booksRaw as List)) {
        final sectionId = row['section_id'] as String;
        countBySection[sectionId] = (countBySection[sectionId] ?? 0) + 1;
      }

      final sections = (sectionsRaw as List)
          .map(
            (e) => SectionEntity.fromJson(
              e as Map<String, dynamic>,
              bookCount: countBySection[e['id'] as String] ?? 0,
            ),
          )
          .toList();

      return Right(sections);
    } on PostgrestException catch (e) {
      _log.warning('getSections: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<BookWithProgressEntity>>> getBooksBySection({
    required String sectionId,
  }) async {
    final networkError = _checkNetwork<List<BookWithProgressEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;

      final booksRaw = await _client
          .from('books')
          .select()
          .eq('section_id', sectionId)
          .eq('status', 'published')
          .order('title', ascending: true)
          .limit(50);

      final books = (booksRaw as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      if (books.isEmpty) return const Right([]);

      final bookIds = books.map((b) => b.id).toList();

      // lessons_public (owner-run view) returns ALL published lessons regardless
      // of entitlement, so the card total is correct for guests too (the base
      // lessons table is entitlement-gated by 0007 and would undercount).
      final lessonsRaw = await _client
          .from('lessons_public')
          .select('id, book_id')
          .eq('status', 'published')
          .inFilter('book_id', bookIds)
          .limit(500);

      final Map<String, List<String>> lessonIdsByBook = {};
      final Map<String, String> lessonIdToBookId = {};
      for (final row in (lessonsRaw as List)) {
        final bookId = row['book_id'] as String;
        final lessonId = row['id'] as String;
        lessonIdsByBook.putIfAbsent(bookId, () => []).add(lessonId);
        lessonIdToBookId[lessonId] = bookId;
      }

      final Map<String, int> completedByBook = {};
      final Set<String> enrolledBookIds = {};

      if (userId != null) {
        if (lessonIdToBookId.isNotEmpty) {
          final allLessonIds = lessonIdToBookId.keys.toList();
          final progressRaw = await _client
              .from('lesson_progress')
              .select('lesson_id')
              .eq('user_id', userId)
              .eq('completed', true)
              .inFilter('lesson_id', allLessonIds);

          for (final row in (progressRaw as List)) {
            final lessonId = row['lesson_id'] as String;
            final bookId = lessonIdToBookId[lessonId];
            if (bookId != null) {
              completedByBook[bookId] = (completedByBook[bookId] ?? 0) + 1;
            }
          }
        }

        final enrollmentsRaw = await _client
            .from('enrollments')
            .select('book_id')
            .eq('user_id', userId)
            .inFilter('book_id', bookIds);

        for (final row in (enrollmentsRaw as List)) {
          enrolledBookIds.add(row['book_id'] as String);
        }
      }

      final result = books.map((book) {
        final total = lessonIdsByBook[book.id]?.length ?? 0;
        final completed = completedByBook[book.id] ?? 0;
        return BookWithProgressEntity(
          book: book,
          totalLessons: total,
          completedLessons: completed,
          progress: completed / (total > 0 ? total : 1),
          isEnrolled: enrolledBookIds.contains(book.id),
        );
      }).toList();

      return Right(result);
    } on PostgrestException catch (e) {
      _log.warning('getBooksBySection: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
