// lib/features/notifications/view/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../models/notification_entity.dart';
import '../cubit_notifs/notifications_cubit.dart';
import '../cubit_notifs/notifications_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (prev, curr) =>
                curr is NotificationsLoaded || curr is NotificationsEmpty,
            builder: (context, state) {
              final hasUnread =
                  state is NotificationsLoaded && state.unreadCount > 0;
              return SheikhyPageHeader(
                title: 'الإشعارات',
                showBack: true,
                action: hasUnread
                    ? TextButton(
                        onPressed: () =>
                            context.read<NotificationsCubit>().markAllRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.s2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'تحديد الكل كمقروء',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.goldLight,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
          const Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        return switch (state) {
          NotificationsInitial() ||
          NotificationsLoading() => const _LoadingView(),
          NotificationsError(:final message) => SheikhyErrorState(
            heading: 'تعذّر تحميل الإشعارات',
            message: message,
            onRetry: () =>
                context.read<NotificationsCubit>().loadNotifications(),
          ),
          NotificationsEmpty() => const SheikhyEmptyState(
            icon: Icons.notifications_none_outlined,
            heading: 'لا توجد إشعارات بعد',
            subtitle: 'ستُخطَر هنا بالدروس والمتون والشهادات.',
          ),
          NotificationsLoaded(:final notifications) => RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () =>
                context.read<NotificationsCubit>().loadNotifications(),
            child: ListView.separated(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter,
                AppSpacing.s3,
                AppSpacing.pageGutter,
                AppSpacing.s7 + context.safeBottom,
              ),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, index) => _NotificationCard(
                notification: notifications[index],
                onTap: () => _handleTap(context, notifications[index]),
              ),
            ),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  void _handleTap(BuildContext context, NotificationEntity notif) {
    context.read<NotificationsCubit>().markRead(notif.id);
    final link = notif.linkUrl;
    if (link == null || link.isEmpty) return;
    if (link.startsWith('/')) {
      context.push(link);
    } else {
      final uri = Uri.tryParse(link);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('جار تحميل المحتوى...', style: AppTextStyles.small),
        ],
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final NotificationEntity notification;
  final VoidCallback onTap;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    String ar(int n) {
      const w = '0123456789';
      const a = '٠١٢٣٤٥٦٧٨٩';
      return n.toString().split('').map((c) {
        final i = w.indexOf(c);
        return i >= 0 ? a[i] : c;
      }).join();
    }

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${ar(diff.inMinutes)} دقيقة';
    if (diff.inHours < 24) return 'منذ ${ar(diff.inHours)} ساعة';
    if (diff.inDays < 7) return 'منذ ${ar(diff.inDays)} يوم';
    return '${ar(dt.day)}/${ar(dt.month)}/${ar(dt.year)}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final typeColor = _NotifIcon.colorFor(notification.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.primaryTint.withValues(alpha: 0.5)
            : AppColors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.border, width: AppBorders.hairline),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.rLg,
        child: Stack(
          children: [
            if (isUnread)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: AppBorders.accent,
                child: ColoredBox(color: typeColor),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadii.rLg,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotifIcon(type: notification.type),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: AppTextStyles.small.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: AppSpacing.s2),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            Text(
                              notification.body,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.inkMuted,
                                letterSpacing: 0,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            Text(
                              _relativeTime(notification.sendAt),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.inkFaint,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifIcon extends StatelessWidget {
  const _NotifIcon({required this.type});

  final String type;

  static Color colorFor(String type) => switch (type) {
    'live_stream' => AppColors.danger,
    'new_lesson' => AppColors.primary,
    'reminder' => AppColors.warning,
    'achievement' => AppColors.goldDeep,
    _ => AppColors.primary,
  };

  static IconData iconFor(String type) => switch (type) {
    'live_stream' => Icons.live_tv_outlined,
    'new_lesson' => Icons.play_circle_outline,
    'reminder' => Icons.alarm_outlined,
    'achievement' => Icons.emoji_events_outlined,
    _ => Icons.notifications_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(type);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconFor(type), color: color, size: 20),
    );
  }
}
