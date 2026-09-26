// lib/features/auth/cubit/auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { student, admin, unknown }

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final UserRole role;

  const AuthAuthenticated({required this.user, required this.role});

  bool get isAdmin => role == UserRole.admin;

  /// A guest is an anonymous Supabase session. Derived from the auth state
  /// itself (the JWT `is_anonymous` claim), not a separate auth system.
  bool get isGuest => user.isAnonymous;

  @override
  List<Object?> get props => [user.id, role, isGuest];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthOffline extends AuthState {}

class AuthEmailConfirmationRequired extends AuthState {}

/// A guest tried to convert to an email that already belongs to an account.
/// Owned by the app-level listener: route to /login (carrying the pending
/// intent) so they can sign into that account and finish the journey.
class AuthGuestEmailTaken extends AuthState {}

/// A guest conversion failed for a non-collision reason. Owned by the app-level
/// listener, which surfaces [message] via a snackbar — the signup page may have
/// been disposed mid-conversion, so it can't show the error inline itself.
class AuthGuestConversionFailed extends AuthState {
  final String message;
  const AuthGuestConversionFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String email;
  const AuthPasswordResetSent(this.email);

  @override
  List<Object?> get props => [email];
}
