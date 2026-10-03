// lib/features/admin/loading_quotes/data/admin_loading_quotes_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/loading_quote_entity.dart';

/// Admin CRUD for the practice-exam loading screen quotes (`loading_quotes`).
/// Postgres errors are mapped to Arabic — never surfaced raw.
class AdminLoadingQuotesRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminLoadingQuotesRepository');

  AdminLoadingQuotesRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// All quotes incl. inactive (admin RLS returns them via is_admin()).
  Future<Either<Failure, List<LoadingQuoteEntity>>> getQuotes() async {
    final net = _checkNetwork<List<LoadingQuoteEntity>>();
    if (net != null) return net;
    try {
      final raw = await _client
          .from('loading_quotes')
          .select()
          .order('sort_order', ascending: true)
          .limit(100);
      final quotes = (raw as List)
          .map((e) => LoadingQuoteEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(quotes);
    } on PostgrestException catch (e) {
      _log.warning('getQuotes: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل النصوص، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LoadingQuoteEntity>> createQuote({
    required String text,
    String? source,
    required int sortOrder,
    required bool isActive,
  }) async {
    final net = _checkNetwork<LoadingQuoteEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('loading_quotes')
          .insert({
            'text': text,
            'source': _nullIfBlank(source),
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .select()
          .single();
      return Right(LoadingQuoteEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createQuote: ${e.message}');
      return Left(ServerFailure('تعذّر حفظ النص، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LoadingQuoteEntity>> updateQuote({
    required String id,
    required String text,
    String? source,
    required bool isActive,
  }) async {
    final net = _checkNetwork<LoadingQuoteEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('loading_quotes')
          .update({
            'text': text,
            'source': _nullIfBlank(source),
            'is_active': isActive,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(LoadingQuoteEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateQuote: ${e.message}');
      return Left(ServerFailure('تعذّر حفظ النص، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LoadingQuoteEntity>> setActive({
    required String id,
    required bool isActive,
  }) async {
    final net = _checkNetwork<LoadingQuoteEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('loading_quotes')
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();
      return Right(LoadingQuoteEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('setActive: ${e.message}');
      return Left(ServerFailure('تعذّر تحديث الحالة، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> updateOrder({
    required String id,
    required int sortOrder,
  }) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('loading_quotes')
          .update({'sort_order': sortOrder})
          .eq('id', id);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('updateOrder: ${e.message}');
      return Left(ServerFailure('تعذّر تحديث الترتيب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteQuote(String id) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('loading_quotes').delete().eq('id', id);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteQuote: ${e.message}');
      return Left(ServerFailure('تعذّر حذف النص، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  String? _nullIfBlank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
