// lib/features/home/data/home_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/banner_entity.dart';
import '../../../models/book_entity.dart';
import '../../../models/book_with_progress_entity.dart';
import '../../../models/suggestion_entity.dart';

class HomeRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('HomeRepository');

  HomeRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<BannerEntity>>> getActiveBanners() async {
    final networkError = _checkNetwork<List<BannerEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('home_banners')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true)
          .limit(10);

      final banners = (response as List)
          .map((e) => BannerEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(banners);
    } on PostgrestException catch (e) {
      _log.warning('getActiveBanners: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Active suggestions for the "مقترحات" home slider. Ordered server-side:
  /// sort_order ASC (NULLs last), then created_at ASC. Failure/empty is handled
  /// by HomeCubit as a hidden section — it must not fail the whole Home load.
  Future<Either<Failure, List<SuggestionEntity>>> getActiveSuggestions() async {
    final networkError = _checkNetwork<List<SuggestionEntity>>();
    if (networkError != null) return networkError;

    try {
      final response = await _client
          .from('suggestions')
          .select()
          // No .limit(): spec allows unlimited suggestions; the slider builds
          // items lazily so fetching all active rows is acceptable.
          .eq('is_active', true)
          .order('sort_order', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);

      final suggestions = (response as List)
          .map((e) => SuggestionEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(suggestions);
    } on PostgrestException catch (e) {
      _log.warning('getActiveSuggestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<BookWithProgressEntity>>> getFeaturedBooks() async {
    final networkError = _checkNetwork<List<BookWithProgressEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;

      final booksRaw = await _client
          .from('books')
          .select()
          .eq('is_featured', true)
          .eq('status', 'published')
          .order('featured_order', ascending: true, nullsFirst: false)
          .limit(20);

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
      _log.warning('getFeaturedBooks: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
