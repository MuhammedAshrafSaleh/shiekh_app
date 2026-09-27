// lib/features/admin/suggestions/data/admin_suggestion_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/suggestion_entity.dart';

/// Admin CRUD for the `suggestions` table. Mirrors [AdminBannerRepository]:
/// same connectivity pre-check, error mapping, and `media` bucket upload.
class AdminSuggestionRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminSuggestionRepository');

  AdminSuggestionRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// All suggestions (active + inactive) for the admin list, ordered the same
  /// way students see them: sort_order ASC (NULLs last), then created_at ASC.
  Future<Either<Failure, List<SuggestionEntity>>> getSuggestions() async {
    final net = _checkNetwork<List<SuggestionEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('suggestions')
          .select()
          .order('sort_order', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true)
          .limit(200);
      return Right(
        (data as List)
            .map((e) => SuggestionEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on PostgrestException catch (e) {
      _log.warning('getSuggestions: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, SuggestionEntity>> createSuggestion({
    required String title,
    required String imageUrl,
    required SuggestionContentType contentType,
    required String contentUrl,
    required int durationSeconds,
    int? sortOrder,
    required bool isActive,
  }) async {
    final net = _checkNetwork<SuggestionEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('suggestions')
          .insert({
            'title': title,
            'image_url': imageUrl,
            'content_type': contentType.value,
            'content_url': contentUrl,
            'duration_seconds': durationSeconds,
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .select()
          .single();
      return Right(SuggestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createSuggestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, SuggestionEntity>> updateSuggestion({
    required String id,
    required String title,
    required String imageUrl,
    required SuggestionContentType contentType,
    required String contentUrl,
    required int durationSeconds,
    int? sortOrder,
    required bool isActive,
  }) async {
    final net = _checkNetwork<SuggestionEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('suggestions')
          .update({
            'title': title,
            'image_url': imageUrl,
            'content_type': contentType.value,
            'content_url': contentUrl,
            'duration_seconds': durationSeconds,
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(SuggestionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateSuggestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> deleteSuggestion(String id) async {
    final net = _checkNetwork<void>();
    if (net != null) return net;
    try {
      await _client.from('suggestions').delete().eq('id', id);
      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('deleteSuggestion: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Uploads to the existing `media` bucket under a `suggestions/` prefix
  /// (same convention banners use with `banners/`).
  Future<Either<Failure, String>> uploadSuggestionImage(
    String localPath,
  ) async {
    final net = _checkNetwork<String>();
    if (net != null) return net;
    try {
      final file = File(localPath);
      final ext = localPath.split('.').last.toLowerCase();
      final fileName =
          'suggestions/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('media')
          .upload(
            fileName,
            file,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      final publicUrl = _client.storage.from('media').getPublicUrl(fileName);
      return Right(publicUrl);
    } on StorageException catch (e) {
      _log.warning('uploadSuggestionImage: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
