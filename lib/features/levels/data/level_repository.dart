// lib/features/levels/data/level_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/book_entity.dart';
import '../../../models/book_with_progress_entity.dart';
import '../../../models/level_entity.dart';

/// Student-facing academic level queries. Only published books, only levels
/// that have at least one published book. Mirrors [SectionRepository].
class LevelRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('LevelRepository');

  LevelRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// Returns levels that have at least one published book, ordered by
  /// `sort_order`. Empty levels are filtered out — students never see them.
  /// Uses a single grouped count over published books (not one query per level).
  Future<Either<Failure, List<LevelEntity>>> getLevels() async {
    final net = _checkNetwork<List<LevelEntity>>();
    if (net != null) return net;

    try {
      final levelsRaw = await _client
          .from('levels')
          .select()
          .order('sort_order', ascending: true)
          .limit(100);

      final booksRaw = await _client
          .from('books')
          .select('level_id')
          .eq('status', 'published')
          .not('level_id', 'is', null)
          .limit(1000);

      final Map<String, int> countByLevel = {};
      for (final row in (booksRaw as List)) {
        final levelId = row['level_id'] as String;
        countByLevel[levelId] = (countByLevel[levelId] ?? 0) + 1;
      }

      final levels = (levelsRaw as List)
          .map(
            (e) => LevelEntity.fromJson(
              e as Map<String, dynamic>,
              bookCount: countByLevel[e['id'] as String] ?? 0,
            ),
          )
          .where((l) => l.bookCount > 0)
          .toList();

      return Right(levels);
    } on PostgrestException catch (e) {
      _log.warning('getLevels: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل المستويات، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Published books in [levelId], ordered by `level_order`, with per-student
  /// lesson progress and enrollment. Reuses the same multi-step join as
  /// [SectionRepository.getBooksBySection].
  Future<Either<Failure, List<BookWithProgressEntity>>> getBooksByLevel(
    String levelId,
  ) async {
    final net = _checkNetwork<List<BookWithProgressEntity>>();
    if (net != null) return net;

    try {
      final userId = _client.auth.currentUser?.id;

      final booksRaw = await _client
          .from('books')
          .select()
          .eq('level_id', levelId)
          .eq('status', 'published')
          .order('level_order', ascending: true, nullsFirst: false)
          .limit(50);

      final books = (booksRaw as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      if (books.isEmpty) return const Right([]);

      final bookIds = books.map((b) => b.id).toList();

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
              .inFilter('lesson_id', allLessonIds)
              .limit(500);

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
            .inFilter('book_id', bookIds)
            .limit(50);

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
      _log.warning('getBooksByLevel: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل الكتب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
