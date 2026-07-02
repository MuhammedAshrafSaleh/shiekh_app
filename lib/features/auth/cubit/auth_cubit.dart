// lib/features/auth/cubit/auth_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../data/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  final _log = Logger('AuthCubit');
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _authSub;
  bool _resolvingRole = false;

  AuthCubit(this._repo) : super(AuthInitial());

  /// Call once after construction. Checks the current session synchronously,
  /// then subscribes to future auth changes (sign-in / sign-out / token refresh).
  /// Subscription is started AFTER the initial check so the stream's immediate
  /// replay of the current session is ignored — we've already handled it.
  Future<void> initialize() async {
    final session = _repo.currentSession;
    if (session == null) {
      emit(AuthUnauthenticated());
    } else {
      await _resolveRole(session.user);
    }
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _repo.authStateChanges.listen((authState) async {
      if (authState.session == null) {
        emit(AuthUnauthenticated());
      } else {
        await _resolveRole(authState.session!.user);
      }
    });
  }

  /// Guards against concurrent / duplicate role lookups (e.g. initialize() and
  /// the stream both firing for the same session on startup).
  Future<void> _resolveRole(User user) async {
    if (_resolvingRole) return;
    _resolvingRole = true;
    try {
      final roleStr = await _repo.getUserRole();
      if (isClosed) return;
      final role = roleStr == 'admin' ? UserRole.admin : UserRole.student;
      emit(AuthAuthenticated(user: user, role: role));
    } finally {
      _resolvingRole = false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    final result = await _repo.signIn(email: email, password: password);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => _log.info('signIn OK'),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    final result = await _repo.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (confirmationRequired) {
        if (confirmationRequired) {
          emit(AuthEmailConfirmationRequired());
        }
        // else: authStateChanges stream fires and emits AuthAuthenticated
      },
    );
  }

  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    final result = await _repo.resetPassword(email);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthPasswordResetSent(email)),
    );
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    final result = await _repo.signOut();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
