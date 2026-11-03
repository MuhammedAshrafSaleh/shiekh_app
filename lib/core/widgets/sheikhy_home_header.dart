// lib/core/widgets/sheikhy_home_header.dart
//
// Heritage home-screen header band: primary green + girih pattern, SafeArea
// top, RTL row (avatar start → greeting → notification bell end).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'girih_background.dart';

class SheikhyHomeHeader extends StatelessWidget {
  const SheikhyHomeHeader({
    super.key,
    required this.name,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  final String name;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: GirihBackground(color: AppColors.goldLight, opacity: 0.14),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s5,
                vertical: AppSpacing.s4,
              ),
              child: Row(
                children: [
                  _Avatar(name: name),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(child: _Greeting(name: name)),
                  _NotificationBell(
                    count: unreadCount,
                    onTap: onNotificationTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  String get _initials {
    if (name.isEmpty) return '؟';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].characters.first;
    return '${parts[0].characters.first}${parts[1].characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryDeep,
      child: Text(
        _initials,
        style: GoogleFonts.reemKufi(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.inkInvert,
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'السلام عليكم.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkInvert.withValues(alpha: 0.70),
            letterSpacing: 0,
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            name,
            style: GoogleFonts.reemKufi(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.inkInvert,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'الإشعارات',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        backgroundColor: Colors.red,
        textColor: Colors.white,
        child: const Icon(
          Icons.notifications_outlined,
          color: AppColors.inkInvert,
        ),
      ),
    );
  }
}
