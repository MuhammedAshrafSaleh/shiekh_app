// lib/core/widgets/show_confirm_dialog.dart
//
// Reusable heritage-styled confirmation dialog. Returns true only when the user
// taps the confirm action; false on cancel / dismiss. Used before destructive
// actions such as deleting an exam/quiz question.
import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'sheikhy_button.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'حذف',
  String cancelLabel = 'إلغاء',
  bool isDestructive = true,
  IconData icon = Icons.delete_outline,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData icon;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? AppColors.danger : AppColors.primary;
    final badgeBg = isDestructive ? AppColors.dangerBg : AppColors.primaryTint;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon badge
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBg,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: accent),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              title,
              style: AppTextStyles.h3.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),

            // Gold divider
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xl,
              ),
              child: Divider(
                color: AppColors.gold.withValues(alpha: 0.4),
                thickness: 1,
                height: 1,
              ),
            ),

            // Optional message
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Confirm action
            if (isDestructive)
              _DangerButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              )
            else
              SheikhyButton.primary(
                fullWidth: true,
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            const SizedBox(height: AppSpacing.sm),

            // Cancel action
            SheikhyButton.secondary(
              fullWidth: true,
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width destructive button matching SheikhyButton's footprint. Kept local
/// because SheikhyButton has no danger variant.
class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DangerButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.danger,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.rMd,
          side: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.85),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.inkInvert,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
