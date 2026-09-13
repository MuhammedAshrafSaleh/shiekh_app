// test/features/auth/auth_repository_test.dart
//
// Retroactive unit coverage for Phase 1 (AuthRepository).
// Covers the success path and each mapped Failure path for every auth method,
// using mocked gotrue clients (no real network / Supabase project needed).
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUserResponse extends Mock implements UserResponse {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late AuthRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    repo = AuthRepository(client);
  });

  group('signIn', () {
    test('returns Right(null) on success', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      final result = await repo.signIn(email: 'a@b.com', password: 'secret1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps invalid credentials to Arabic AuthFailure', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('Invalid login credentials'));

      final result = await repo.signIn(email: 'a@b.com', password: 'wrong');

      expect(
        result,
        const Left<Failure, void>(
          AuthFailure('البريد الإلكتروني أو كلمة المرور غير صحيحة'),
        ),
      );
    });

    test('maps unconfirmed email to Arabic AuthFailure', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('Email not confirmed'));

      final result = await repo.signIn(email: 'a@b.com', password: 'secret1');

      expect(
        result,
        const Left<Failure, void>(
          AuthFailure('يرجى تأكيد بريدك الإلكتروني أولاً'),
        ),
      );
    });

    test('maps an unexpected (non-Auth) error to ServerFailure', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('socket blew up'));

      final result = await repo.signIn(email: 'a@b.com', password: 'secret1');

      expect(
        result,
        const Left<Failure, void>(
          ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'),
        ),
      );
    });
  });

  group('signUp', () {
    test(
      'returns Right(true) when confirmation required (no session)',
      () async {
        when(
          () => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => AuthResponse());

        final result = await repo.signUp(
          email: 'a@b.com',
          password: 'secret1',
          fullName: 'اسم',
        );

        expect(result, const Right<Failure, bool>(true));
      },
    );

    test('maps duplicate email to Arabic AuthFailure (CC-27)', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(const AuthException('User already registered'));

      final result = await repo.signUp(
        email: 'a@b.com',
        password: 'secret1',
        fullName: 'اسم',
      );

      expect(
        result,
        const Left<Failure, bool>(
          AuthFailure('هذا البريد الإلكتروني مسجّل مسبقاً'),
        ),
      );
    });

    test('maps weak password to Arabic AuthFailure', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        const AuthException('Password should be at least 6 characters'),
      );

      final result = await repo.signUp(
        email: 'a@b.com',
        password: '123',
        fullName: 'اسم',
      );

      expect(
        result,
        const Left<Failure, bool>(
          AuthFailure('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
        ),
      );
    });
  });

  group('resetPassword', () {
    test('returns Right(null) on success', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});

      final result = await repo.resetPassword('a@b.com');

      expect(result, const Right<Failure, void>(null));
    });

    test(
      'maps rate limit to Arabic AuthFailure (CC-30 neutral flow)',
      () async {
        when(
          () => auth.resetPasswordForEmail(
            any(),
            redirectTo: any(named: 'redirectTo'),
          ),
        ).thenThrow(const AuthException('email rate limit exceeded'));

        final result = await repo.resetPassword('a@b.com');

        expect(
          result,
          const Left<Failure, void>(
            AuthFailure('محاولات كثيرة، يرجى الانتظار قليلاً'),
          ),
        );
      },
    );
  });

  group('signOut', () {
    test('returns Right(null) on success', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      final result = await repo.signOut();

      expect(result, const Right<Failure, void>(null));
    });

    test('maps any error to ServerFailure', () async {
      when(() => auth.signOut()).thenThrow(Exception('boom'));

      final result = await repo.signOut();

      expect(
        result,
        const Left<Failure, void>(ServerFailure('تعذّر تسجيل الخروج')),
      );
    });
  });

  group('getUserRole', () {
    test('returns null when there is no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      final role = await repo.getUserRole();

      expect(role, isNull);
    });
  });

  group('signInAnonymously', () {
    test('returns Right(null) on success', () async {
      when(
        () => auth.signInAnonymously(),
      ).thenAnswer((_) async => AuthResponse());

      final result = await repo.signInAnonymously();

      expect(result, const Right<Failure, void>(null));
    });

    test('maps disabled anonymous provider to Arabic AuthFailure', () async {
      when(
        () => auth.signInAnonymously(),
      ).thenThrow(const AuthException('Anonymous sign-ins are disabled'));

      final result = await repo.signInAnonymously();

      expect(
        result,
        const Left<Failure, void>(AuthFailure('وضع الزائر غير مُفعّل حالياً')),
      );
    });

    test('maps an unexpected (non-Auth) error to ServerFailure', () async {
      when(() => auth.signInAnonymously()).thenThrow(Exception('boom'));

      final result = await repo.signInAnonymously();

      expect(
        result,
        const Left<Failure, void>(
          ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'),
        ),
      );
    });
  });

  group('convertGuest', () {
    test('returns Right(null) on success', () async {
      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => _MockUserResponse());

      final result = await repo.convertGuest(
        email: 'a@b.com',
        password: 'secret1',
        fullName: 'اسم',
      );

      expect(result, const Right<Failure, void>(null));
    });

    test('maps already-in-use email to the Arabic collision message', () async {
      when(() => auth.updateUser(any())).thenThrow(
        const AuthException('email address is already in use by another user'),
      );

      final result = await repo.convertGuest(
        email: 'taken@b.com',
        password: 'secret1',
        fullName: 'اسم',
      );

      expect(
        result,
        const Left<Failure, void>(
          AuthFailure('هذا البريد الإلكتروني مسجّل مسبقاً'),
        ),
      );
    });

    test(
      'maps EMAIL_TAKEN trigger error to the same collision message',
      () async {
        when(
          () => auth.updateUser(any()),
        ).thenThrow(const AuthException('EMAIL_TAKEN'));

        final result = await repo.convertGuest(
          email: 'taken@b.com',
          password: 'secret1',
          fullName: 'اسم',
        );

        expect(
          result,
          const Left<Failure, void>(
            AuthFailure('هذا البريد الإلكتروني مسجّل مسبقاً'),
          ),
        );
      },
    );

    test('maps an unexpected (non-Auth) error to ServerFailure', () async {
      when(() => auth.updateUser(any())).thenThrow(Exception('boom'));

      final result = await repo.convertGuest(
        email: 'a@b.com',
        password: 'secret1',
        fullName: 'اسم',
      );

      expect(
        result,
        const Left<Failure, void>(
          ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'),
        ),
      );
    });
  });
}
