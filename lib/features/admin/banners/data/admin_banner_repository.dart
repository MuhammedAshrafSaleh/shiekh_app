// lib/features/admin/banners/data/admin_banner_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/banner_entity.dart';
import '../../../../models/book_entity.dart';

class AdminBannerRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminBannerRepository');

  AdminBannerRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<BannerEntity>>> getBanners() async {
    final net = _checkNetwork<List<BannerEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('home_banners')
          .select()
          .order('order_index')
          .limit(50);
      return Right((data as List)
          .map((e) => BannerEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getBanners: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<BookEntity>>> getPublishedBooks() async {
    final net = _checkNetwork<List<BookEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('books')
          .select('id, title, section_id, status, review_status, is_featured, featured_order')
          .eq('status', 'published')
          .order('title')
          .limit(200);
      return Right((data as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getPublishedBooks: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BannerEntity>> createBanner({
    required String title,
    String? description,
    String? imageUrl,
    String? linkedBookId, // CC-26: nullable target
    String? externalLink,
    required int orderIndex,
    required bool isActive,
  }) async {
    final net = _checkNetwork<BannerEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('home_banners')
          .insert({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'linked_book_id': linkedBookId,
            'external_link': externalLink,
            'order_index': orderIndex,
            'is_active': isActive,
          })
          .select()
          .single();
      return Right(BannerEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createBanner: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, BannerEntity>> updateBanner({
    required String id,
    required String title,
    String? description,
    String? imageUrl,
    String? linkedBookId,
    String? externalLink,
    required int orderIndex,
    required bool isActive,
  }) async {
    final net = _checkNetwork<BannerEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('home_banners')
          .update({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'linked_book_id': linkedBookId,
            'external_link': externalLink,
            'order_index': orderIndex,
            'is_active': isActive,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(BannerEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateBanner: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> deleteBanner(String id) async {
    final net = _checkNetwork<void>();
    if (net != null) return net;
    try {
      await _client.from('home_banners').delete().eq('id', id);
      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('deleteBanner: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, String>> uploadBannerImage(String localPath) async {
    final net = _checkNetwork<String>();
    if (net != null) return net;
    try {
      final file = File(localPath);
      final ext = localPath.split('.').last.toLowerCase();
      final fileName =
          'banners/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('media').upload(
            fileName,
            file,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      final publicUrl =
          _client.storage.from('media').getPublicUrl(fileName);
      return Right(publicUrl);
    } on StorageException catch (e) {
      _log.warning('uploadBannerImage: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
