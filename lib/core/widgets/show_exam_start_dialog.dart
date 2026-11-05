// lib/core/widgets/show_exam_start_dialog.dart
//
// Heritage-themed exam confirmation dialogs:
//   • showExamStartDialog  — warn before starting (attempt will be consumed if left)
//   • showLeaveQuizDialog  — warn before leaving mid-quiz (answers will be lost)
// Both return true = confirmed, false = cancelled.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sheikhy_button.dart';

Future<bool> showExamStartDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (_) => const _ExamStartDialog(),
  );
  return result ?? false;
}

class _ExamStartDialog extends StatelessWidget {
  const _ExamStartDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.s8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
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
                  color: AppColors.primaryTint,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: AppBorders.control,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.assignment_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Title
            Text(
              'قبل أن تبدأ الاختبار',
              style: AppTextStyles.h3.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),

            // Gold divider line
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s7,
              ),
              child: Divider(
                color: AppColors.gold.withValues(alpha: 0.4),
                thickness: AppBorders.hairline,
                height: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Warning tile — attempt loss
            _InfoTile(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.warning,
              iconBg: AppColors.warning.withValues(alpha: 0.10),
              text:
                  'إذا غادرت الاختبار بعد البدء ستُحتسب هذه المحاولة مستخدمة ولن تتمكن من استردادها.',
            ),
            const SizedBox(height: AppSpacing.s3),

            // Info tile — internet
            _InfoTile(
              icon: Icons.wifi_rounded,
              iconColor: AppColors.info,
              iconBg: AppColors.infoBg,
              text: 'تأكد من استقرار اتصالك بالإنترنت طوال فترة الاختبار.',
            ),
            const SizedBox(height: AppSpacing.s5),

            // Start button
            SheikhyButton.primary(
              fullWidth: true,
              label: 'ابدأ الاختبار',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.s3),

            // Cancel button
            SheikhyButton.secondary(
              fullWidth: true,
              label: 'إلغاء',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leave quiz dialog ────────────────────────────────────────────────────────

Future<bool> showLeaveQuizDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (_) => const _LeaveQuizDialog(),
  );
  return result ?? false;
}

class _LeaveQuizDialog extends StatelessWidget {
  const _LeaveQuizDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.s8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
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
                  color: AppColors.dangerBg,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.30),
                    width: AppBorders.control,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  size: 32,
                  color: AppColors.danger,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Title
            Text(
              'مغادرة الاختبار؟',
              style: AppTextStyles.h3.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),

            // Gold divider
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s7,
              ),
              child: Divider(
                color: AppColors.gold.withValues(alpha: 0.4),
                thickness: AppBorders.hairline,
                height: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Warning tile
            _InfoTile(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.warning,
              iconBg: AppColors.warning.withValues(alpha: 0.10),
              text:
                  'إذا غادرت الآن ستضيع إجاباتك وستُحتسب هذه المحاولة مستخدمة.',
            ),
            const SizedBox(height: AppSpacing.s5),

            // Continue button (primary — stay)
            SheikhyButton.primary(
              fullWidth: true,
              label: 'المتابعة في الاختبار',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.s3),

            // Leave button (secondary danger-tinted)
            SheikhyButton.secondary(
              fullWidth: true,
              label: 'مغادرة',
              icon: const Icon(Icons.exit_to_app_rounded),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared info tile ─────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String text;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.border, width: AppBorders.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.s1),
              child: Text(
                text,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
