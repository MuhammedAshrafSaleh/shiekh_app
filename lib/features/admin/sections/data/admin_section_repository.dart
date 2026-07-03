// lib/features/admin/sections/data/admin_section_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/section_entity.dart';

class AdminSectionRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminSectionRepository');

  AdminSectionRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<SectionEntity>>> getSections() async {
    final net = _checkNetwork<List<SectionEntity>>();
    if (net != null) return net;
    try {
      final raw =
          await _client.from('sections').select().order('name').limit(50);

      final booksRaw = await _client
          .from('books')
          .select('section_id')
          .limit(1000);

      final Map<String, int> countBySection = {};
      for (final row in (booksRaw as List)) {
        final sectionId = row['section_id'] as String;
        countBySection[sectionId] = (countBySection[sectionId] ?? 0) + 1;
      }

      final sections = (raw as List)
          .map((e) => SectionEntity.fromJson(
                e as Map<String, dynamic>,
                bookCount: countBySection[e['id'] as String] ?? 0,
              ))
          .toList();

      return Right(sections);
    } on PostgrestException catch (e) {
      _log.warning('getSections: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, SectionEntity>> createSection({
    required String name,
    required String icon,
    String? description,
  }) async {
    final net = _checkNetwork<SectionEntity>();
    if (net != null) return net;
    try {
      final userId = _client.auth.currentUser?.id;
      final data = await _client
          .from('sections')
          .insert({
            'name': name,
            'icon': icon,
            'description': description,
            'created_by': userId,
          })
          .select()
          .single();
      return Right(SectionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createSection: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, SectionEntity>> updateSection({
    required String id,
    required String name,
    required String icon,
    String? description,
  }) async {
    final net = _checkNetwork<SectionEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('sections')
          .update({
            'name': name,
            'icon': icon,
            'description': description,
          })
          .eq('id', id)
          .select()
          .single();
      return Right(SectionEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateSection: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> deleteSection(String id) async {
    final net = _checkNetwork<void>();
    if (net != null) return net;
    try {
      await _client.from('sections').delete().eq('id', id);
      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('deleteSection: ${e.message}');
      if (e.code == '23503') {
        return Left(DeleteRestrictedFailure(
            'لا يمكن حذف القسم لأنه يحتوي على كتب مرتبطة. يرجى حذف أو نقل الكتب أولاً.'));
      }
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
