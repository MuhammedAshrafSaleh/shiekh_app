// lib/features/achievements/data/achievements_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../models/certificate_entity.dart';

class AchievementsData {
  final int completedLessons;
  final int certificateCount;
  final Map<DateTime, int> activityByDate; // date → event count (for heatmap)

  const AchievementsData({
    required this.completedLessons,
    required this.certificateCount,
    required this.activityByDate,
  });

  // Estimated hours: ~15 minutes per completed lesson
  int get estimatedStudyHours =>
      ((completedLessons * 15) / 60).ceil();
}

class AchievementsRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AchievementsRepository');

  AchievementsRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, AchievementsData>> getAchievementsData() async {
    final networkError = _checkNetwork<AchievementsData>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      // Parallel queries
      final progressFuture = _client
          .from('lesson_progress')
          .select('completed, updated_at')
          .eq('user_id', userId)
          .eq('completed', true)
          .limit(1000);

      final certsFuture = _client
          .from('certificates')
          .select('id')
          .eq('user_id', userId);

      final attemptsFuture = _client
          .from('final_exam_attempts')
          .select('submitted_at')
          .eq('user_id', userId)
          .limit(200);

      final results =
          await Future.wait([progressFuture, certsFuture, attemptsFuture]);

      final progressRows = results[0] as List;
      final certsRows = results[1] as List;
      final attemptsRows = results[2] as List;

      final completedLessons = progressRows.length;
      final certificateCount = certsRows.length;

      // Build activity map: day → count of events
      final activityRaw = <DateTime, int>{};

      for (final row in progressRows) {
        final updatedAt = row['updated_at'] as String?;
        if (updatedAt == null) continue;
        final day = _toDay(DateTime.parse(updatedAt));
        activityRaw[day] = (activityRaw[day] ?? 0) + 1;
      }

      for (final row in attemptsRows) {
        final submittedAt = row['submitted_at'] as String?;
        if (submittedAt == null) continue;
        final day = _toDay(DateTime.parse(submittedAt));
        activityRaw[day] = (activityRaw[day] ?? 0) + 1;
      }

      // Map event counts to 1–4 buckets for heatmap colour levels (plan M)
      final activityBucketed = activityRaw.map((day, count) {
        final bucket = count >= 8
            ? 4
            : count >= 5
                ? 3
                : count >= 3
                    ? 2
                    : 1;
        return MapEntry(day, bucket);
      });

      return Right(AchievementsData(
        completedLessons: completedLessons,
        certificateCount: certificateCount,
        activityByDate: activityBucketed,
      ));
    } on PostgrestException catch (e) {
      _log.warning('getAchievementsData: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, List<CertificateEntity>>> getCertificates() async {
    final networkError = _checkNetwork<List<CertificateEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final response = await _client
          .from('certificates')
          .select('*, books(title)')
          .eq('user_id', userId)
          .order('issued_at', ascending: false)
          .limit(50);

      final certs = (response as List)
          .map((e) =>
              CertificateEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return Right(certs);
    } on PostgrestException catch (e) {
      _log.warning('getCertificates: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  DateTime _toDay(DateTime dt) =>
      DateTime(dt.toLocal().year, dt.toLocal().month, dt.toLocal().day);
}
