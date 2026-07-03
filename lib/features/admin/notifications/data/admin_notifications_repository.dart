// lib/features/admin/notifications/data/admin_notifications_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';
import '../../../../models/notification_entity.dart';

class AdminNotificationsRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminNotificationsRepository');

  AdminNotificationsRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<NotificationEntity>>> getNotifications() async {
    final net = _checkNetwork<List<NotificationEntity>>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('notifications')
          .select('id, type, title, body, link_url, send_at, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      return Right((data as List)
          .map((e) =>
              NotificationEntity.fromJson(e as Map<String, dynamic>))
          .toList());
    } on PostgrestException catch (e) {
      _log.warning('getNotifications: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, NotificationEntity>> createNotification({
    required String type,
    required String title,
    required String body,
    String? linkUrl,
    required DateTime sendAt,
  }) async {
    final net = _checkNetwork<NotificationEntity>();
    if (net != null) return net;
    try {
      final data = await _client
          .from('notifications')
          .insert({
            'type': type,
            'title': title,
            'body': body,
            'link_url': linkUrl,
            'send_at': sendAt.toIso8601String(),
          })
          .select()
          .single();
      return Right(NotificationEntity.fromJson(data));
    } on PostgrestException catch (e) {
      _log.warning('createNotification: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> deleteNotification(
      String notificationId) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('deleteNotification: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
