// lib/features/admin/levels/data/admin_level_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/level_entity.dart';

/// Admin CRUD + reorder for academic levels (`levels`). Mirrors
/// [AdminSectionRepository]; the duplicate-name constraint (`uq_levels_name`,
/// Postgres code 23505) is mapped to an Arabic [ValidationFailure], never a
/// raw error. Reorder delegates to the transactional `reorder_levels` RPC.
class AdminLevelRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminLevelRepository');

  AdminLevelRepository(this._client, this._connectivity);

  static const _duplicateNameMessage = 'اسم المستوى موجود بالفعل';

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  /// All levels ordered by display order, each with the count of books assigned
  /// to it (all statuses — the admin sees drafts too). The count comes from a
  /// single grouped fetch, not one query per level.
  Future<Either<Failure, List<LevelEntity>>> getLevels() async {
    final net = _checkNetwork<List<LevelEntity>>();
    if (net != null) return net;
    try {
      final raw = await _client
          .from('levels')
          .select()
          .order('sort_order', ascending: true)
          .limit(100);

      final booksRaw = await _client
          .from('books')
          .select('level_id')
          .not('level_id', 'is', null)
          .limit(1000);

      final Map<String, int> countByLevel = {};
      for (final row in (booksRaw as List)) {
        final levelId = row['level_id'] as String;
        countByLevel[levelId] = (countByLevel[levelId] ?? 0) + 1;
      }

      final levels = (raw as List)
          .map(
            (e) => LevelEntity.fromJson(
              e as Map<String, dynamic>,
              bookCount: countByLevel[e['id'] as String] ?? 0,
            ),
          )
          .toList();

      return Right(levels);
    } on PostgrestException catch (e) {
      _log.warning('getLevels: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل المستويات، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LevelEntity>> createLevel({
    required String name,
  }) async {
    final net = _checkNetwork<LevelEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('levels')
          .insert({'name': name, 'sort_order': await _nextSortOrder()})
          .select()
          .single();
      return Right(LevelEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createLevel: ${e.message}');
      if (e.code == '23505') {
        return Left(ValidationFailure(_duplicateNameMessage));
      }
      return Left(ServerFailure('تعذّر حفظ المستوى، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, LevelEntity>> updateLevel({
    required String id,
    required String name,
  }) async {
    final net = _checkNetwork<LevelEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('levels')
          .update({'name': name})
          .eq('id', id)
          .select()
          .single();
      return Right(LevelEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('updateLevel: ${e.message}');
      if (e.code == '23505') {
        return Left(ValidationFailure(_duplicateNameMessage));
      }
      return Left(ServerFailure('تعذّر حفظ المستوى، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Hard delete. `books.level_id` is `ON DELETE SET NULL` and a BEFORE DELETE
  /// trigger clears `level_order`, so the books are simply unassigned — never
  /// deleted. No FK-restrict path here (unlike sections).
  Future<Either<Failure, Unit>> deleteLevel(String id) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.from('levels').delete().eq('id', id);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteLevel: ${e.message}');
      return Left(ServerFailure('تعذّر حذف المستوى، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Transactional reorder via the `reorder_levels` RPC (0029) — every
  /// `sort_order` update runs in one server-side transaction.
  Future<Either<Failure, Unit>> reorderLevels(
    List<({String id, int sortOrder})> updates,
  ) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      final payload = updates
          .map((u) => {'id': u.id, 'sort_order': u.sortOrder})
          .toList();
      await _client.rpc('reorder_levels', params: {'p_updates': payload});
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('reorderLevels: ${e.message}');
      return Left(ServerFailure('تعذّر تحديث الترتيب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Next append position = current max(sort_order) + 1 (1-based, 1 if empty).
  Future<int> _nextSortOrder() async {
    final rows = await _client
        .from('levels')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return 1;
    return ((list.first as Map<String, dynamic>)['sort_order'] as int) + 1;
  }
}
