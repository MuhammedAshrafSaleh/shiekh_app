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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.startFloat,
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