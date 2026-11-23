// test/features/admin/admin_level_repository_test.dart
//
// Unit tests for AdminLevelRepository — covers for every method:
//   • Offline guard → NetworkFailure
//   • PostgrestException → ServerFailure (Arabic, never raw)
//   • Duplicate-name (uq_levels_name, code 23505) → ValidationFailure on
//     create AND update
//   • reorderLevels delegates to the reorder_levels RPC
//   • LevelEntity.fromJson — pure parse
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/levels/data/admin_level_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/level_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

const _duplicate = PostgrestException(
  message: 'duplicate key value violates unique constraint "uq_levels_name"',
  code: '23505',
);

void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late AdminLevelRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminLevelRepository(client, connectivity);
  });

  void goOnlineButThrow(PostgrestException e) {
    when(() => connectivity.state).thenReturn(_online);
    when(() => client.from(any())).thenThrow(e);
  }

  // ── getLevels ───────────────────────────────────────────────────────────
  group('getLevels', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getLevels();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getLevels();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the levels table', () async {
      goOnlineButThrow(const PostgrestException(message: 'ok'));

      await repo.getLevels();

      verify(() => client.from('levels')).called(greaterThanOrEqualTo(1));
    });
  });

  // ── createLevel ─────────────────────────────────────────────────────────
  group('createLevel', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.createLevel(name: 'السنة التمهيدية');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on generic PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'insert error'));

      final result = await repo.createLevel(name: 'المستوى الأول');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps duplicate-name (23505) to ValidationFailure, not raw', () async {
      goOnlineButThrow(_duplicate);

      final result = await repo.createLevel(name: 'المستوى الأول');

      result.fold((f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message, 'اسم المستوى موجود بالفعل');
      }, (_) => fail('expected Left'));
    });
  });

  // ── updateLevel ─────────────────────────────────────────────────────────
  group('updateLevel', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.updateLevel(
        id: 'lvl-1',
        name: 'المستوى الثاني',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on generic PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'update error'));

      final result = await repo.updateLevel(
        id: 'lvl-1',
        name: 'المستوى الثاني',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps duplicate-name (23505) to ValidationFailure, not raw', () async {
      goOnlineButThrow(_duplicate);

      final result = await repo.updateLevel(id: 'lvl-1', name: 'المستوى الأول');

      result.fold((f) {
        expect(f, isA<ValidationFailure>());
        expect(f.message, 'اسم المستوى موجود بالفعل');
      }, (_) => fail('expected Left'));
    });
  });

  // ── deleteLevel ─────────────────────────────────────────────────────────
  group('deleteLevel', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteLevel('lvl-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'delete error'));

      final result = await repo.deleteLevel('lvl-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── reorderLevels ─────────────────────────────────────────────────────────
  group('reorderLevels', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.reorderLevels([(id: 'lvl-1', sortOrder: 1)]);

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('calls the reorder_levels RPC with the payload', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'boom'));

      await repo.reorderLevels([
        (id: 'lvl-1', sortOrder: 1),
        (id: 'lvl-2', sortOrder: 2),
      ]);

      verify(
        () => client.rpc(
          'reorder_levels',
          params: {
            'p_updates': [
              {'id': 'lvl-1', 'sort_order': 1},
              {'id': 'lvl-2', 'sort_order': 2},
            ],
          },
        ),
      ).called(1);
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'rpc error'));

      final result = await repo.reorderLevels([(id: 'lvl-1', sortOrder: 1)]);

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── LevelEntity.fromJson ──────────────────────────────────────────────────
  group('LevelEntity.fromJson', () {
    test('parses fields and defaults bookCount to 0', () {
      final level = LevelEntity.fromJson({
        'id': 'lvl-1',
        'name': 'السنة التمهيدية',
        'sort_order': 3,
      });

      expect(level.id, 'lvl-1');
      expect(level.name, 'السنة التمهيدية');
      expect(level.sortOrder, 3);
      expect(level.bookCount, 0);
    });

    test('carries an injected bookCount', () {
      final level = LevelEntity.fromJson({
        'id': 'lvl-1',
        'name': 'المستوى الأول',
        'sort_order': 1,
      }, bookCount: 7);

      expect(level.bookCount, 7);
    });
  });
}
