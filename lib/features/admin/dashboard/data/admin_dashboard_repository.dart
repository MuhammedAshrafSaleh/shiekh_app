// lib/features/admin/dashboard/data/admin_dashboard_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/book_entity.dart';

class AdminStats {
  final int totalBooks;
  final int totalStudents;
  final int totalLessons;
  final int pendingQa;

  const AdminStats({
    required this.totalBooks,
    required this.totalStudents,
    required this.totalLessons,
    required this.pendingQa,
  });
}

class AdminDashboardRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminDashboardRepository');

  AdminDashboardRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, AdminStats>> getStats() async {
    final net = _checkNetwork<AdminStats>();
    if (net != null) return net;
    try {
      final results = await Future.wait([
        _client.from('books').select('id').limit(1000),
        _client
            .from('users')
            .select('id')
            .eq('role', 'student')
            .limit(10000),
        _client.from('lessons').select('id').limit(10000),
        _client
            .from('student_questions')
            .select('id')
            .eq('status', 'pending')
            .limit(1000),
      ]);

      return Right(AdminStats(
        totalBooks: (results[0] as List).length,
        totalStudents: (results[1] as List).length,
        totalLessons: (results[2] as List).length,
        pendingQa: (results[3] as List).length,
      ));
    } on PostgrestException catch (e) {
      _log.warning('getStats: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<BookEntity>>> getAllBooks() async {
    final net = _checkNetwork<List<BookEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('books')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      final books = (data as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(books);
    } on PostgrestException catch (e) {
      _log.warning('getAllBooks: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> deleteBook(String bookId) async {
    final net = _checkNetwork<void>();
    if (net != null) return net;
    try {
      // Unlink banners that reference this book (nullable FK, no CASCADE).
      await _client
          .from('home_banners')
          .update({'linked_book_id': null}).eq('linked_book_id', bookId);
      // Delete lessons explicitly; quiz questions and lesson progress
      // cascade automatically via DB FK constraints.
      await _client.from('lessons').delete().eq('book_id', bookId);
      await _client.from('books').delete().eq('id', bookId);
      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('deleteBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
