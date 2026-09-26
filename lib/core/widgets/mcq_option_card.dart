// lib/core/widgets/mcq_option_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../audio/app_sound.dart';
import '../audio/sound_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

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
    final Color cardBg;
    final Color cardBorder;
    final Color textColor;

    switch (optionState) {
      case McqOptionState.idle:
        cardBg = AppColors.surface;
        cardBorder = AppColors.border;
        textColor = AppColors.ink;
      case McqOptionState.selected:
        cardBg = AppColors.primary;
        cardBorder = AppColors.primaryDeep;
        textColor = AppColors.inkInvert;
      case McqOptionState.correct:
        cardBg = AppColors.success.withValues(alpha: 0.08);
        cardBorder = AppColors.success;
        textColor = AppColors.success;
      case McqOptionState.incorrect:
        cardBg = AppColors.dangerBg;
        cardBorder = AppColors.danger;
        textColor = AppColors.danger;
    }

    final effectiveTap = onTap == null
        ? null
        : () {
            context.read<SoundService>().play(AppSound.select);
            onTap!();
          };

    return GestureDetector(
      onTap: effectiveTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.s3),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.s4,
          AppSpacing.s3,
          AppSpacing.s4,
          AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: AppRadii.rMd,
          border: Border.all(color: cardBorder, width: AppBorders.control),
        ),
        child: Row(
          children: [
            _OptionCircle(label: label, state: optionState),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCircle extends StatelessWidget {
  final String label;
  final McqOptionState state;

  const _OptionCircle({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color circleBg;
    final Color circleBorder;
    final Widget circleChild;

    switch (state) {
      case McqOptionState.idle:
        circleBg = Colors.transparent;
        circleBorder = AppColors.border;
        circleChild = Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        );
      case McqOptionState.selected:
        circleBg = AppColors.surface;
        circleBorder = Colors.transparent;
        circleChild = Icon(Icons.check_rounded, size: 18, color: AppColors.primary);
      case McqOptionState.correct:
        circleBg = AppColors.success.withValues(alpha: 0.15);
        circleBorder = Colors.transparent;
        circleChild = const Icon(Icons.check_rounded, size: 18, color: AppColors.success);
      case McqOptionState.incorrect:
        circleBg = AppColors.danger.withValues(alpha: 0.12);
        circleBorder = Colors.transparent;
        circleChild = const Icon(Icons.close_rounded, size: 18, color: AppColors.danger);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: circleBg,
        border: Border.all(color: circleBorder, width: AppBorders.control),
      ),
      alignment: Alignment.center,
      child: circleChild,
    );
  }
}
