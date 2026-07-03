// lib/features/certificates/data/certificate_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/certificate_entity.dart';

class CertificateRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('CertificateRepository');

  CertificateRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<CertificateEntity>>> getCertificates() async {
    final networkError = _checkNetwork<List<CertificateEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('certificates')
          .select()
          .eq('user_id', userId)
          .order('issued_at', ascending: false)
          .limit(50);

      final certs = (response as List)
          .map((e) =>
              CertificateEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(certs);
    } on PostgrestException catch (e) {
      _log.warning('getCertificates: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, CertificateEntity?>> getCertificateForBook(
      String bookId) async {
    final networkError = _checkNetwork<CertificateEntity?>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Right(null);

      final response = await _client
          .from('certificates')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .limit(1);

      final rows = response as List;
      if (rows.isEmpty) return const Right(null);
      return Right(
          CertificateEntity.fromJson(rows.first as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      _log.warning('getCertificateForBook: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
