// lib/features/admin/notifications/cubit/admin_notifications_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/notification_entity.dart';

abstract class AdminNotificationsState extends Equatable {
  const AdminNotificationsState();
  @override
  List<Object?> get props => [];
}

class AdminNotificationsInitial extends AdminNotificationsState {}

class AdminNotificationsLoading extends AdminNotificationsState {}

class AdminNotificationsLoaded extends AdminNotificationsState {
  final List<NotificationEntity> notifications;
  const AdminNotificationsLoaded(this.notifications);
  @override
  List<Object?> get props => [notifications];
}

class AdminNotificationsEmpty extends AdminNotificationsState {}

class AdminNotificationsSending extends AdminNotificationsState {}

class AdminNotificationsSent extends AdminNotificationsState {}

class AdminNotificationsError extends AdminNotificationsState {
  final String message;
  const AdminNotificationsError(this.message);
  @override
  List<Object?> get props => [message];
}
