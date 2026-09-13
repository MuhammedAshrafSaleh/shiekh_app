// test/features/admin/admin_dashboard_repository_test.dart
//
// Unit tests for AdminDashboardRepository — covers:
//   • Offline guard → NetworkFailure (before any Supabase call)
//   • PostgrestException → ServerFailure
//   • deleteBook with FK-violation (code 23503) → DeleteRestrictedFailure (CC-4)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/dashboard/data/admin_dashboard_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late AdminDashboardRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminDashboardRepository(client, connectivity);
  });

  // ── getStats ──────────────────────────────────────────────────────────────
  group('getStats', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getStats();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'stats error'));

      final result = await repo.getStats();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── getAllBooks ────────────────────────────────────────────────────────────
  group('getAllBooks', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getAllBooks();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getAllBooks();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the books table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.getAllBooks();

      verify(() => client.from('books')).called(1);
    });
  });

  // ── deleteBook — CC-4 strong-delete warning, CC-3 restrict ────────────────
  group('deleteBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteBook('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test(
      'returns DeleteRestrictedFailure on FK-violation (code 23503)',
      () async {
        when(() => connectivity.state).thenReturn(_online);
        when(() => client.from(any())).thenThrow(
          const PostgrestException(message: 'fk error', code: '23503'),
        );

        final result = await repo.deleteBook('book-id');

        expect(result.isLeft(), true);
        result.fold(
          (f) => expect(f, isA<DeleteRestrictedFailure>()),
          (_) => fail('expected Left(DeleteRestrictedFailure)'),
        );
      },
    );

    test('returns ServerFailure on other PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'other error', code: '42501'),
      );

      final result = await repo.deleteBook('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left(ServerFailure)'),
      );
    });
  });

  // ── AdminStats model ───────────────────────────────────────────────────────
  group('AdminStats', () {
    test('holds all four counters', () {
      const stats = AdminStats(
        totalBooks: 12,
        totalStudents: 450,
        totalLessons: 87,
        pendingQa: 3,
      );

      expect(stats.totalBooks, 12);
      expect(stats.totalStudents, 450);
      expect(stats.totalLessons, 87);
      expect(stats.pendingQa, 3);
    });
  });
}
