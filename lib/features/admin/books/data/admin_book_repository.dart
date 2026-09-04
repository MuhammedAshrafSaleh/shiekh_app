// lib/features/admin/books/data/admin_book_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/book_entity.dart';
import '../../../../models/section_entity.dart';

class AdminBookRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminBookRepository');

  AdminBookRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<SectionEntity>>> getSections() async {
    final net = _checkNetwork<List<SectionEntity>>();
    if (net != null) return net;
    try {
      final raw =
          await _client.from('sections').select().order('name', ascending: true).limit(50);
      return Right((raw as List)
          .map((e) => SectionEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getSections: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Returns count of currently featured books (not counting [excludeId]).
  Future<Either<Failure, int>> getFeaturedCount({
    String? excludeId,
  }) async {
    final net = _checkNetwork<int>();
    if (net != null) return net;
    try {
      var query =
          _client.from('books').select('id').eq('is_featured', true);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final data = await query.limit(10);
      return Right((data as List).length);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BookEntity>> getBook(String bookId) async {
    final net = _checkNetwork<BookEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('books')
          .select()
          .eq('id', bookId)
          .single();
      return Right(BookEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('getBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, String>> uploadCoverImage(String localPath) async {
    final net = _checkNetwork<String>();
    if (net != null) return net;
    try {
      final file = File(localPath);
      final ext = localPath.split('.').last.toLowerCase();
      final fileName =
          'covers/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('media').upload(
            fileName,
            file,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      final publicUrl =
          _client.storage.from('media').getPublicUrl(fileName);
      return Right(publicUrl);
    } on StorageException catch (e) {
      _log.warning('uploadCoverImage: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BookEntity>> createBook({
    required String sectionId,
    required String title,
    String? description,
    String? coverImageUrl,
    required String status,
    required String reviewStatus,
    required bool isFeatured,
    int? featuredOrder,
  }) async {
    final net = _checkNetwork<BookEntity>();
    if (net != null) return net;
    try {
      final userId = _client.auth.currentUser?.id;
      final data = await _client
          .from('books')
          .insert({
            'section_id': sectionId,
            'title': title,
            'description': description,
            'cover_image_url': coverImageUrl,
            'status': status,
            'review_status': reviewStatus,
            'is_featured': isFeatured,
            'featured_order': featuredOrder,
            'created_by': userId,
          })
          .select()
          .single();
      return Right(BookEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BookEntity>> updateBook({
    required String id,
    required String sectionId,
    required String title,
    String? description,
    String? coverImageUrl,
    required String status,
    required String reviewStatus,
    required bool isFeatured,
    int? featuredOrder,
  }) async {
    final net = _checkNetwork<BookEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('books')
          .update({
            'section_id': sectionId,
            'title': title,
            'description': description,
            'cover_image_url': coverImageUrl,
            'status': status,
            'review_status': reviewStatus,
            'is_featured': isFeatured,
            'featured_order': featuredOrder,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(BookEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
