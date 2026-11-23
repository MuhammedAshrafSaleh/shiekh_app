// lib/features/admin/levels/data/admin_level_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/assignable_book_entity.dart';
import '../../../../models/book_entity.dart';
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

  // ── Books within a level (Phase 3) ─────────────────────────────────────────

  /// The books assigned to [levelId], ordered by `level_order` (admin sees all
  /// statuses). Reorder reassigns `level_order` from list position, so nulls —
  /// if any slipped in — sort last.
  Future<Either<Failure, List<BookEntity>>> getBooksInLevel(
    String levelId,
  ) async {
    final net = _checkNetwork<List<BookEntity>>();
    if (net != null) return net;
    try {
      final raw = await _client
          .from('books')
          .select()
          .eq('level_id', levelId)
          .order('level_order', ascending: true, nullsFirst: false)
          .limit(500);
      final books = (raw as List)
          .map((e) => BookEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(books);
    } on PostgrestException catch (e) {
      _log.warning('getBooksInLevel: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل كتب المستوى، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Books available to add to [excludeLevelId]: those with no level, plus those
  /// in a DIFFERENT level (shown so the admin can MOVE them). Books already in
  /// this level are excluded. Each carries its current level name for the badge.
  Future<Either<Failure, List<AssignableBookEntity>>> getAssignableBooks(
    String excludeLevelId,
  ) async {
    final net = _checkNetwork<List<AssignableBookEntity>>();
    if (net != null) return net;
    try {
      final raw = await _client
          .from('books')
          .select('id, title, cover_image_url, level_id, levels(name)')
          .or('level_id.is.null,level_id.neq.$excludeLevelId')
          .order('title', ascending: true)
          .limit(1000);
      final books = (raw as List)
          .map((e) => AssignableBookEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(books);
    } on PostgrestException catch (e) {
      _log.warning('getAssignableBooks: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل الكتب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Assigns [bookId] to [levelId] at the end of that level's order. If the book
  /// already belongs to another level, this overwrite IS the move — the old
  /// level simply loses it (a gap in its order is harmless).
  Future<Either<Failure, Unit>> addBookToLevel({
    required String bookId,
    required String levelId,
  }) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('books')
          .update({
            'level_id': levelId,
            'level_order': await _nextLevelOrder(levelId),
          })
          .eq('id', bookId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('addBookToLevel: ${e.message}');
      return Left(ServerFailure('تعذّر إضافة الكتاب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Unlinks [bookId] from its level — clears `level_id` + `level_order` only.
  /// The book itself is never deleted.
  Future<Either<Failure, Unit>> removeBookFromLevel(String bookId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('books')
          .update({'level_id': null, 'level_order': null})
          .eq('id', bookId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('removeBookFromLevel: ${e.message}');
      return Left(ServerFailure('تعذّر إزالة الكتاب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Transactional reorder of books within one level via the scoped
  /// `reorder_level_books(p_level_id, p_updates)` RPC — the `p_level_id` guard
  /// means a bad payload cannot touch another level's books.
  Future<Either<Failure, Unit>> reorderLevelBooks({
    required String levelId,
    required List<({String id, int levelOrder})> updates,
  }) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      final payload = updates
          .map((u) => {'id': u.id, 'level_order': u.levelOrder})
          .toList();
      await _client.rpc(
        'reorder_level_books',
        params: {'p_level_id': levelId, 'p_updates': payload},
      );
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('reorderLevelBooks: ${e.message}');
      return Left(ServerFailure('تعذّر تحديث الترتيب، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Next append position within [levelId] = max(level_order)+1 (1 if empty).
  Future<int> _nextLevelOrder(String levelId) async {
    final rows = await _client
        .from('books')
        .select('level_order')
        .eq('level_id', levelId)
        .order('level_order', ascending: false, nullsFirst: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return 1;
    final top = (list.first as Map<String, dynamic>)['level_order'] as int?;
    return (top ?? 0) + 1;
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
