// lib/core/widgets/status_badge.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BadgeStatus { published, draft, answered, pending, completed, inReview }

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BadgeStatus.published => ('منشور', Colors.green),
      BadgeStatus.draft => ('مسودة', Colors.grey),
      BadgeStatus.answered => ('تمت الإجابة', Colors.green),
      BadgeStatus.pending => ('في الانتظار', AppColors.gold),
      BadgeStatus.completed => ('مكتمل', Colors.green),
      BadgeStatus.inReview => ('قيد المراجعة', AppColors.gold),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
