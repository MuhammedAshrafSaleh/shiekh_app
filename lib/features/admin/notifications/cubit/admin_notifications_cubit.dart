// lib/features/admin/notifications/cubit/admin_notifications_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_notifications_repository.dart';
import 'admin_notifications_state.dart';

class AdminNotificationsCubit extends Cubit<AdminNotificationsState> {
  final AdminNotificationsRepository _repo;

  AdminNotificationsCubit(this._repo) : super(AdminNotificationsInitial());

  Future<void> load() async {
    emit(AdminNotificationsLoading());
    final result = await _repo.getNotifications();
    if (isClosed) return;
    result.fold(
      (f) => emit(AdminNotificationsError(f.message)),
      (list) => list.isEmpty
          ? emit(AdminNotificationsEmpty())
          : emit(AdminNotificationsLoaded(list)),
    );
  }

  Future<bool> send({
    required String type,
    required String title,
    required String body,
    String? linkUrl,
    required DateTime sendAt,
  }) async {
    emit(AdminNotificationsSending());
    final result = await _repo.createNotification(
      type: type,
      title: title,
      body: body,
      linkUrl: linkUrl,
      sendAt: sendAt,
    );
    if (isClosed) return false;
    return result.fold(
      (f) {
        emit(AdminNotificationsError(f.message));
        return false;
      },
      (_) {
        emit(AdminNotificationsSent());
        load();
        return true;
      },
    );
  }

  Future<void> delete(String notificationId) async {
    final result = await _repo.deleteNotification(notificationId);
    if (isClosed) return;
    result.fold((f) => emit(AdminNotificationsError(f.message)), (_) => load());
  }
}
