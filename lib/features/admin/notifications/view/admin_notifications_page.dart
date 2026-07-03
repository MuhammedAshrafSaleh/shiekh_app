// lib/features/admin/notifications/view/admin_notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/notification_entity.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../cubit/admin_notifications_state.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminNotificationsCubit, AdminNotificationsState>(
      listener: (context, state) {
        if (state is AdminNotificationsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الإشعارات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<AdminNotificationsCubit>().load(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('إشعار جديد'),
            onPressed: () async {
              await context.push('/admin/notifications/new');
              if (context.mounted) {
                context.read<AdminNotificationsCubit>().load();
              }
            },
          ),
          body: switch (state) {
            AdminNotificationsLoading() =>
              const Center(child: CircularProgressIndicator()),
            AdminNotificationsError() => ErrorState(
                message: state.message,
                onRetry: () =>
                    context.read<AdminNotificationsCubit>().load(),
              ),
            AdminNotificationsEmpty() => EmptyState(
                icon: Icons.notifications_none_outlined,
                message: 'لا توجد إشعارات بعد',
                actionLabel: 'إرسال إشعار',
                onAction: () =>
                    context.push('/admin/notifications/new'),
              ),
            AdminNotificationsLoaded() => RefreshIndicator(
                onRefresh: () =>
                    context.read<AdminNotificationsCubit>().load(),
                child: ListView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      100),
                  itemCount: state.notifications.length,
                  itemBuilder: (context, i) => _NotificationTile(
                    notification: state.notifications[i],
                  ),
                ),
              ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final typeLabels = {
      'general': 'عام',
      'live_stream': 'بث مباشر',
      'new_lesson': 'درس جديد',
      'reminder': 'تذكير',
      'achievement': 'إنجاز',
    };
    final typeIcons = {
      'general': Icons.notifications_outlined,
      'live_stream': Icons.live_tv_outlined,
      'new_lesson': Icons.play_lesson_outlined,
      'reminder': Icons.alarm_outlined,
      'achievement': Icons.emoji_events_outlined,
    };

    final isSent = notification.sendAt.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            typeIcons[notification.type] ?? Icons.notifications_outlined,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabels[notification.type] ?? notification.type,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  isSent ? Icons.check_circle_outline : Icons.schedule,
                  size: 12,
                  color: isSent ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 2),
                Text(
                  isSent ? 'أُرسل' : 'مجدول',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSent ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
        isThreeLine: true,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف الإشعار'),
        content: const Text('هل تريد حذف هذا الإشعار نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context
                  .read<AdminNotificationsCubit>()
                  .delete(notification.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
