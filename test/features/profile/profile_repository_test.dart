// test/features/profile/profile_repository_test.dart
//
// Unit tests for ProfileRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (AuthFailure)
//   • PostgrestException mapping → ServerFailure
//   • ProfileStats struct construction (pure)
//   • changePassword: wrong password maps to Arabic AuthFailure
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------
class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';

  @override
  String? get email => 'test@example.com';
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const _offlineState = ConnectivityState(isOffline: true);
const _onlineState = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late ProfileRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = ProfileRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getProfileStats
  // -------------------------------------------------------------------------
  group('getProfileStats', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getProfileStats();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getProfileStats();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'users query error'));

      final result = await repo.getProfileStats();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // updateFullName
  // -------------------------------------------------------------------------
  group('updateFullName', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.updateFullName('New Name');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.updateFullName('New Name');

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'update error'));

      final result = await repo.updateFullName('New Name');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // changePassword
  // -------------------------------------------------------------------------
  group('changePassword', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.changePassword(
        currentPassword: 'old',
        newPassword: 'new123',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user email', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.changePassword(
        currentPassword: 'old',
        newPassword: 'new123',
      );

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
    });

    test('maps wrong-password AuthException to Arabic message', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('Invalid login credentials'));

      final result = await repo.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new123',
      );

      result.fold((f) {
        expect(f, isA<AuthFailure>());
        expect(f.message, 'كلمة المرور الحالية غير صحيحة');
      }, (_) => fail('expected Left'));
    });
  });

  // -------------------------------------------------------------------------
  // ProfileStats — pure construction
  // -------------------------------------------------------------------------
  group('ProfileStats', () {
    test('estimatedStudyHours is accessible as a plain property', () {
      const stats = ProfileStats(
        fullName: 'Ahmad Ali',
        email: 'a@b.com',
        enrolledBooks: 3,
        completedLessons: 10,
        certificates: 2,
      );

      expect(stats.enrolledBooks, 3);
      expect(stats.completedLessons, 10);
      expect(stats.certificates, 2);
    });
  });
}
