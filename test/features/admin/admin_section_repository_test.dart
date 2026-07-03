// test/features/admin/admin_section_repository_test.dart
//
// Unit tests for AdminSectionRepository — covers:
//   • Offline guard → NetworkFailure
//   • PostgrestException → ServerFailure
//   • deleteSection FK-violation (code 23503) → DeleteRestrictedFailure (CC-3)
//   • SectionEntity.fromJson — pure parse
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/sections/data/admin_section_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/section_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}
class _MockGoTrueClient extends Mock implements GoTrueClient {}
class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late AdminSectionRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
    repo = AdminSectionRepository(client, connectivity);
  });

  // ── getSections ───────────────────────────────────────────────────────────
  group('getSections', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getSections();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getSections();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries sections table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'ok'));

      await repo.getSections();

      verify(() => client.from('sections')).called(greaterThanOrEqualTo(1));
    });
  });

  // ── createSection ─────────────────────────────────────────────────────────
  group('createSection', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.createSection(
        name: 'علوم الحديث',
        icon: 'hadith',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'insert error'));

      final result = await repo.createSection(
        name: 'علوم الحديث',
        icon: 'hadith',
        description: 'وصف القسم',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── updateSection ─────────────────────────────────────────────────────────
  group('updateSection', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.updateSection(
        id: 'sec-id',
        name: 'الفقه',
        icon: 'fiqh',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'update error'));

      final result = await repo.updateSection(
        id: 'sec-id',
        name: 'الفقه',
        icon: 'fiqh',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── deleteSection — CC-3 restrict ─────────────────────────────────────────
  group('deleteSection', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteSection('sec-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('CC-3: returns DeleteRestrictedFailure on FK violation (23503)', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'fk', code: '23503'));

      final result = await repo.deleteSection('sec-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<DeleteRestrictedFailure>());
          // Error message mentions books
          expect(f.message, contains('كتب'));
        },
        (_) => fail('expected Left(DeleteRestrictedFailure)'),
      );
    });

    test('returns ServerFailure on other PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'perm', code: '42501'));

      final result = await repo.deleteSection('sec-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left(ServerFailure)'),
      );
    });
  });

  // ── SectionEntity.fromJson — pure parse ───────────────────────────────────
  group('SectionEntity.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'sec-1',
        'name': 'العقيدة',
        'icon': 'aqeedah',
        'description': 'قسم العقيدة الإسلامية',
        'created_by': 'user-1',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entity = SectionEntity.fromJson(json, bookCount: 5);

      expect(entity.id, 'sec-1');
      expect(entity.name, 'العقيدة');
      expect(entity.icon, 'aqeedah');
      expect(entity.description, 'قسم العقيدة الإسلامية');
      expect(entity.bookCount, 5);
    });

    test('parses null description correctly', () {
      final json = {
        'id': 'sec-2',
        'name': 'الفقه',
        'icon': 'fiqh',
        'description': null,
        'created_by': null,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entity = SectionEntity.fromJson(json);

      expect(entity.description, isNull);
      expect(entity.bookCount, 0);
    });
  });
}
