// lib/features/profile/data/profile_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';

class ProfileStats {
  final String fullName;
  final String email;
  final int enrolledBooks;
  final int completedLessons;
  final int certificates;

  const ProfileStats({
    required this.fullName,
    required this.email,
    required this.enrolledBooks,
    required this.completedLessons,
    required this.certificates,
  });
}

class ProfileRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('ProfileRepository');

  ProfileRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, ProfileStats>> getProfileStats() async {
    final networkError = _checkNetwork<ProfileStats>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final userFuture = _client
          .from('users')
          .select('full_name, email')
          .eq('id', userId)
          .single();

      final enrolledFuture = _client
          .from('enrollments')
          .select('id')
          .eq('user_id', userId);

      final lessonsFuture = _client
          .from('lesson_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('completed', true);

      final certsFuture = _client
          .from('certificates')
          .select('id')
          .eq('user_id', userId);

      final user = await userFuture;
      final enrolled = await enrolledFuture;
      final lessons = await lessonsFuture;
      final certs = await certsFuture;

      return Right(ProfileStats(
        fullName: user['full_name'] as String? ?? '',
        email: user['email'] as String? ?? '',
        enrolledBooks: enrolled.length,
        completedLessons: lessons.length,
        certificates: certs.length,
      ));
    } on PostgrestException catch (e) {
      _log.warning('getProfileStats: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> updateFullName(String fullName) async {
    final networkError = _checkNetwork<void>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      await _client
          .from('users')
          .update({'full_name': fullName})
          .eq('id', userId);

      // Keep auth metadata in sync
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': fullName}),
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('updateFullName: ${e.message}');
      return Left(ServerFailure(e.message));
    } on AuthException catch (e) {
      _log.warning('updateFullName auth: ${e.message}');
      return Left(AuthFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final networkError = _checkNetwork<void>();
    if (networkError != null) return networkError;

    try {
      final email = _client.auth.currentUser?.email;
      if (email == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      // Re-authenticate to verify current password
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const Right(null);
    } on AuthException catch (e) {
      _log.warning('changePassword: ${e.message}');
      if (e.message.contains('Invalid login credentials')) {
        return Left(AuthFailure('كلمة المرور الحالية غير صحيحة'));
      }
      return Left(AuthFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
