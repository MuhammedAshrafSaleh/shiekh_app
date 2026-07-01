// lib/core/widgets/mcq_option_card.dart
import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

enum McqOptionState { idle, selected, correct, incorrect }

class McqOptionCard extends StatelessWidget {
  final String label;
  final String text;
  final McqOptionState optionState;
  final VoidCallback? onTap;

  const McqOptionCard({
    super.key,
    required this.label,
    required this.text,
    this.optionState = McqOptionState.idle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, border, textColor) = switch (optionState) {
      McqOptionState.idle => (
          scheme.surface,
          scheme.outline,
          scheme.onSurface,
        ),
      McqOptionState.selected => (
          scheme.primaryContainer,
          scheme.primary,
          scheme.onPrimaryContainer,
        ),
      McqOptionState.correct => (
          Colors.green.shade50,
          Colors.green,
          Colors.green.shade800,
        ),
      McqOptionState.incorrect => (
          Colors.red.shade50,
          Colors.red,
          Colors.red.shade800,
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: border.withValues(alpha: 0.15),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(text, style: TextStyle(color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
}
