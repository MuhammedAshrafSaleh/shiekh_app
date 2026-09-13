// lib/features/notifications/data/notifications_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../models/notification_entity.dart';
import '../cubit/connectivity_cubit.dart';

class NotificationsRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('NotificationsRepository');

  NotificationsRepository(this._client, this._connectivity);

  String? get currentUserId => _client.auth.currentUser?.id;

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, List<NotificationEntity>>> getNotifications() async {
    final networkError = _checkNetwork<List<NotificationEntity>>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      // Fetch all notifications (past send_at) alongside user's reads
      final response = await _client
          .from('notifications')
          .select(
            'id, type, title, body, link_url, send_at, created_at, notification_reads!left(id)',
          )
          .lte('send_at', DateTime.now().toIso8601String())
          .order('send_at', ascending: false)
          .limit(100);

      final list = (response as List).map((row) {
        final reads = row['notification_reads'] as List? ?? [];
        final isRead = reads.isNotEmpty;
        return NotificationEntity.fromJson(
          Map<String, dynamic>.from(row as Map),
          isRead: isRead,
        );
      }).toList();

      return Right(list);
    } on PostgrestException catch (e) {
      _log.warning('getNotifications: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> markAllRead(List<String> unreadIds) async {
    final networkError = _checkNetwork<void>();
    if (networkError != null) return networkError;

    if (unreadIds.isEmpty) return const Right(null);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      final rows = unreadIds
          .map((nid) => {'user_id': userId, 'notification_id': nid})
          .toList();

      await _client
          .from('notification_reads')
          .upsert(rows, onConflict: 'user_id,notification_id');

      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('markAllRead: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, void>> markRead(String notificationId) async {
    final networkError = _checkNetwork<void>();
    if (networkError != null) return networkError;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return Left(AuthFailure('يجب تسجيل الدخول أولاً'));

      await _client.from('notification_reads').upsert({
        'user_id': userId,
        'notification_id': notificationId,
      }, onConflict: 'user_id,notification_id');
      return const Right(null);
    } on PostgrestException catch (e) {
      _log.warning('markRead: ${e.message}');
      return Left(ServerFailure(e.message));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  /// Opens two Realtime channels so that both broadcast (target_user_id IS NULL)
  /// and personal (target_user_id = userId) INSERT events are delivered without
  /// relying on the Realtime server applying RLS — each channel has a server-side
  /// column filter that restricts which rows it receives.
  /// The caller is responsible for unsubscribing both returned channels.
  List<RealtimeChannel> subscribeToNewNotifications(
    String userId,
    void Function(Map<String, dynamic> payload) onInsert,
  ) {
    final broadcast = _client
        .channel('notif-broadcast')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: null,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();

    final personal = _client
        .channel('notif-personal-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: userId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();

    return [broadcast, personal];
  }
}
