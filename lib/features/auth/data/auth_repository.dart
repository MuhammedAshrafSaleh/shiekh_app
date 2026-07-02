// lib/features/auth/data/auth_repository.dart
import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        redirectTo: 'io.sheikhy.app://reset-callback',
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
        raw.contains('already been registered')) {
      return 'هذا البريد الإلكتروني مسجّل مسبقاً';
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
