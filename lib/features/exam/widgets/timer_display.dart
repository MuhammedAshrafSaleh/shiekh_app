// lib/features/exam/widgets/timer_display.dart
import 'package:flutter/material.dart';

import '../../../core/utils/media_duration.dart';

class TimerDisplay extends StatelessWidget {
  final int secondsRemaining;

  const TimerDisplay({super.key, required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsRemaining <= 60;
    final formatted = formatMediaDuration(Duration(seconds: secondsRemaining));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: isUrgent ? Colors.red : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            formatted,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isUrgent ? Colors.red : null,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}
