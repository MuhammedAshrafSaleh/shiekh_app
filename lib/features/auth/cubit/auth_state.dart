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

  @override
  List<Object?> get props => [user.id, role];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
