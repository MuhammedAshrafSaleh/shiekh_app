// lib/core/widgets/progress_bar.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final double height;

  const ProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final isComplete = value >= 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: isComplete ? AppColors.progressGold : AppColors.progressGreen,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
