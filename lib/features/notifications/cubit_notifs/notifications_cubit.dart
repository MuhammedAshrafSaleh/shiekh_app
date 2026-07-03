// lib/features/notifications/cubit_notifs/notifications_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/notification_entity.dart';
import '../data/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repo;
  RealtimeChannel? _channel;

  NotificationsCubit(this._repo) : super(NotificationsInitial());

  Future<void> loadNotifications() async {
    emit(NotificationsLoading());
    final result = await _repo.getNotifications();
    result.fold(
      (failure) => emit(NotificationsError(failure.message)),
      (list) {
        if (list.isEmpty) {
          emit(NotificationsEmpty());
        } else {
          emit(NotificationsLoaded(list));
        }
        _subscribeRealtime();
      },
    );
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _repo.subscribeToNewNotifications(_onNewNotification);
  }

  void _onNewNotification(Map<String, dynamic> payload) {
    final current = state;
    if (current is! NotificationsLoaded && current is! NotificationsEmpty) {
      return;
    }

    final newNotif = NotificationEntity.fromJson(payload, isRead: false);
    final existing = current is NotificationsLoaded
        ? List<NotificationEntity>.from(current.notifications)
        : <NotificationEntity>[];

    // Prepend; avoid duplicates
    if (existing.any((n) => n.id == newNotif.id)) return;
    existing.insert(0, newNotif);
    emit(NotificationsLoaded(existing));
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final unreadIds =
        current.notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    final result = await _repo.markAllRead(unreadIds);
    result.fold(
      (_) => null,
      (_) {
        final updated = current.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        emit(NotificationsLoaded(updated));
      },
    );
  }

  Future<void> markRead(String notificationId) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    await _repo.markRead(notificationId);

    final updated = current.notifications.map((n) {
      return n.id == notificationId ? n.copyWith(isRead: true) : n;
    }).toList();
    emit(NotificationsLoaded(updated));
  }

  @override
  Future<void> close() async {
    await _channel?.unsubscribe();
    return super.close();
  }
}
