// lib/core/widgets/primary_button.dart
import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(label),
            ),
    );
  }
}
