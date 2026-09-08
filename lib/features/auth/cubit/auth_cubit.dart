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
  // True while an in-place guest conversion is being resolved. A failed
  // updateUser can surface a transient sign-out on the auth stream even though
  // the anonymous session is still valid; this guards against dropping the
  // guest to onboarding during that window.
  bool _convertingGuest = false;

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
        // Ignore a transient sign-out surfaced by a failed guest conversion —
        // the anonymous session is still valid, so the guest must not be dropped
        // to onboarding. convertGuest() handles the failure explicitly.
        if (_convertingGuest) return;
        emit(AuthUnauthenticated());
      } else {
        _convertingGuest = false;
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
      // Guests (anonymous sessions) are always student-role; skip the DB role
      // lookup entirely. `isGuest` is derived from user.isAnonymous in the state.
      if (user.isAnonymous) {
        if (isClosed) return;
        emit(AuthAuthenticated(user: user, role: UserRole.student));
        return;
      }
      final roleStr = await _repo.getUserRole();
      if (isClosed) return;
      final role = roleStr == 'admin' ? UserRole.admin : UserRole.student;
      emit(AuthAuthenticated(user: user, role: role));
    } finally {
      _resolvingRole = false;
    }
  }

  /// Starts a guest (anonymous) session. On success the auth stream fires and
  /// `_resolveRole` emits an AuthAuthenticated with `isGuest == true`.
  ///
  /// Guarded against re-entry: if a sign-in is already in flight (AuthLoading),
  /// a second tap is ignored so we never open two anonymous sessions.
  Future<void> continueAsGuest() async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    final result = await _repo.signInAnonymously();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => _log.info('continueAsGuest OK'),
    );
  }

  /// Upgrades the current anonymous session into a real email account in place.
  /// On success the auth stream re-resolves the role as a registered user.
  /// On failure (most importantly, the email already exists) emits AuthError
  /// so the UI can surface the message and offer to sign in instead.
  Future<void> convertGuest({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    _convertingGuest = true;
    final result = await _repo.convertGuest(
      email: email,
      password: password,
      fullName: fullName,
    );
    await result.fold(
      (failure) async {
        // Surface the error, then re-assert the guest session. A failed
        // conversion must NOT drop the anonymous auth.uid: the user stays a
        // guest on the signup screen with the error visible, and a corrected
        // retry still upgrades in place (never creates a second account).
        emit(AuthError(failure.message));
        final session = _repo.currentSession;
        if (session != null) {
          emit(AuthAuthenticated(user: session.user, role: UserRole.student));
        }
        // Release the sign-out guard after the current event burst so any late
        // side-effect event from the failed updateUser is ignored first.
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!isClosed) _convertingGuest = false;
        });
      },
      (_) async {
        _log.info('convertGuest OK');
        _convertingGuest = false;
        // updateUser keeps the OLD anonymous JWT, so the is_anonymous claim
        // stays true until refreshed. Force a fresh JWT so the claim flips to
        // false server-side (RLS reads auth.jwt()->>'is_anonymous') and the
        // User object reflects the registered identity — otherwise the app and
        // Supabase RLS both keep treating the user as a guest.
        final refreshed = await _repo.refreshSession();
        await refreshed.fold(
          (failure) async => emit(AuthError(failure.message)),
          (user) async {
            if (user != null) await _resolveRole(user);
          },
        );
      },
    );
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
