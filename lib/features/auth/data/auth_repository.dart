// lib/features/auth/data/auth_repository.dart
import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';

class AuthRepository {
  final SupabaseClient _client;
  final _log = Logger('AuthRepository');

  AuthRepository(this._client);

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<Either<Failure, void>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const Right(null);
    } on AuthException catch (e) {
      _log.warning('signIn failed: ${e.message}');
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('signIn unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  // Returns true if email confirmation is required, false if signed in immediately.
  Future<Either<Failure, bool>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      final confirmationRequired = response.session == null;
      return Right(confirmationRequired);
    } on AuthException catch (e) {
      _log.warning('signUp failed: ${e.message}');
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('signUp unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  /// Starts a guest session via Supabase anonymous auth. The guest gets a real
  /// `auth.uid` (with `is_anonymous = true` in the JWT), so existing RLS keeps
  /// working on one code path. Requires "Anonymous sign-ins" enabled in the
  /// project's Auth settings — otherwise Supabase returns `anonymous_provider_disabled`.
  Future<Either<Failure, void>> signInAnonymously() async {
    try {
      await _client.auth.signInAnonymously();
      return const Right(null);
    } on AuthException catch (e) {
      _log.warning('signInAnonymously failed: ${e.message}');
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('signInAnonymously unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  /// Upgrades the current anonymous session into a real email account IN PLACE
  /// (same `auth.uid`). With email confirmation disabled the change takes effect
  /// immediately and the JWT's `is_anonymous` flips to false; the
  /// `on_auth_user_converted` DB trigger syncs the profile row's email/full_name.
  ///
  /// The main failure case is [email] already belonging to another account:
  /// Supabase rejects the link at the auth layer and this returns an
  /// [AuthFailure] carrying the localized "already registered" message so the UI
  /// can steer the user to sign in instead (no second user is ever created).
  Future<Either<Failure, void>> convertGuest({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
          data: {'full_name': fullName},
        ),
      );
      return const Right(null);
    } on AuthException catch (e) {
      _log.warning('convertGuest failed: ${e.message}');
      // The email belongs to another account — surface a distinct failure so the
      // app can route to sign-in (rather than string-matching the message).
      if (e.code == 'email_exists') {
        return Left(EmailAlreadyInUseFailure(_mapAuthError(e.message)));
      }
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('convertGuest unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  /// Forces a token refresh so a freshly-converted guest gets a NEW JWT with
  /// `is_anonymous: false`. `updateUser` (see [convertGuest]) swaps in the new
  /// User object but keeps the old anonymous access token, so the `is_anonymous`
  /// claim — which server-side RLS reads via `auth.jwt()` — stays `true` until
  /// the session is refreshed. Returns the refreshed [User].
  Future<Either<Failure, User?>> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return Right(response.session?.user);
    } on AuthException catch (e) {
      _log.warning('refreshSession failed: ${e.message}');
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('refreshSession unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  Future<Either<Failure, void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Right(null);
    } catch (e) {
      _log.severe('signOut: $e');
      return Left(ServerFailure('تعذّر تسجيل الخروج'));
    }
  }

  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: '${AppConfig.deepLinkScheme}://reset-callback',
      );
      return const Right(null);
    } on AuthException catch (e) {
      _log.warning('resetPassword failed: ${e.message}');
      return Left(AuthFailure(_mapAuthError(e.message)));
    } catch (e) {
      _log.severe('resetPassword unexpected: $e');
      return Left(ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مجدداً'));
    }
  }

  Future<String?> getUserRole() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final data = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      return data['role'] as String?;
    } catch (e) {
      _log.warning('getUserRole failed: $e');
      return null;
    }
  }

  String _mapAuthError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (raw.contains('Email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    }
    if (raw.contains('User already registered') ||
        raw.contains('already been registered') ||
        raw.contains('already in use') ||
        raw.contains('email_exists') ||
        raw.contains('identity_already_exists') ||
        raw.contains('EMAIL_TAKEN')) {
      return 'هذا البريد الإلكتروني مسجّل مسبقاً';
    }
    if (raw.contains('Anonymous sign-ins are disabled') ||
        raw.contains('anonymous_provider_disabled')) {
      return 'وضع الزائر غير مُفعّل حالياً';
    }
    if (raw.contains('Password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (raw.contains('rate limit')) {
      return 'محاولات كثيرة، يرجى الانتظار قليلاً';
    }
    return 'حدث خطأ، يرجى المحاولة مجدداً';
  }
}
