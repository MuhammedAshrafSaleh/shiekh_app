// lib/core/widgets/sheikhy_button.dart
//
// Heritage buttons. Variants: primary / secondary / text (+ SheikhyIconButton).
// Sizes md(48) / sm(38). Disabled when onPressed == null. Loading shows a
// spinner while keeping the button's footprint. Specs: DESIGN_SYSTEM.md §5.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum SheikhyButtonVariant { primary, secondary, text }

enum SheikhyButtonSize { md, sm }

class SheikhyButton extends StatelessWidget {
  const SheikhyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SheikhyButtonVariant.primary,
    this.size = SheikhyButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  const SheikhyButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SheikhyButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  }) : variant = SheikhyButtonVariant.primary;

  const SheikhyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SheikhyButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  }) : variant = SheikhyButtonVariant.secondary;

  const SheikhyButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SheikhyButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  }) : variant = SheikhyButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final SheikhyButtonVariant variant;
  final SheikhyButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final bool fullWidth;

  bool get _disabled => onPressed == null || isLoading;
  double get _height => size == SheikhyButtonSize.md ? 48 : 38;

  @override
  Widget build(BuildContext context) {
    if (variant == SheikhyButtonVariant.text) return _buildText();

    final isPrimary = variant == SheikhyButtonVariant.primary;
    final Color bg;
    final Color fg;
    final BorderSide side;
    if (_disabled) {
      bg = AppColors.paperSunk;
      fg = AppColors.inkFaint;
      side = const BorderSide(color: AppColors.border, width: 1);
    } else if (isPrimary) {
      bg = AppColors.primary;
      fg = AppColors.inkInvert;
      side = BorderSide(color: AppColors.primaryDeep, width: 1);
    } else {
      bg = AppColors.paper;
      fg = AppColors.primary;
      side = const BorderSide(color: AppColors.gold, width: 1.5);
    }

    final showInsetHighlight = isPrimary && !_disabled;

    Widget content = Container(
      constraints: BoxConstraints(minHeight: _height),
      alignment: Alignment.center,
      padding: EdgeInsetsDirectional.symmetric(
        // 28px (md) / 18px (sm) horizontal keeps Arabic labels on one line.
        horizontal: size == SheikhyButtonSize.md
            ? AppSpacing.s5 + AppSpacing.s1
            : AppSpacing.s4 + 2,
        vertical: AppSpacing.s2,
      ),
      child: _content(fg),
    );

    if (showInsetHighlight) {
      content = Stack(
        children: [
          content,
          PositionedDirectional(
            top: 1,
            start: 1,
            end: 1,
            child: IgnorePointer(
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  color: AppColors.goldLight.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd, side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _disabled ? null : onPressed,
        child: content,
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : IntrinsicWidth(child: button);
  }

  Widget _buildText() {
    final color = _disabled ? AppColors.inkFaint : AppColors.goldDeep;
    return InkWell(
      onTap: _disabled ? null : onPressed,
      borderRadius: AppRadii.rMd,
      child: Container(
        constraints: BoxConstraints(minHeight: _height),
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: isLoading
            ? _spinner(color)
            : Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: AppTextStyles.buttonLabel.copyWith(
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.goldLight,
                  decorationThickness: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _content(Color fg) {
    if (isLoading) return _spinner(fg);
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
      style: AppTextStyles.buttonLabel.copyWith(
        color: fg,
        fontSize: size == SheikhyButtonSize.md ? 17 : 15,
      ),
    );
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme(data: IconThemeData(color: fg, size: 18), child: icon!),
        const SizedBox(width: AppSpacing.s2),
        text,
      ],
    );
  }

  Widget _spinner(Color color) => SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

/// 48×48 square icon button. [filled] uses primary bg + gold icon; otherwise a
/// paper bg with border + goldDeep icon.
class SheikhyIconButton extends StatelessWidget {
  const SheikhyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bg = disabled
        ? AppColors.paperSunk
        : (filled ? AppColors.primary : AppColors.paper);
    final iconColor = disabled
        ? AppColors.inkFaint
        : (filled ? AppColors.goldLight : AppColors.goldDeep);
    final side = filled
        ? BorderSide.none
        : const BorderSide(color: AppColors.border, width: 1.5);

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd, side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconTheme(
            data: IconThemeData(color: iconColor, size: 20),
            child: Center(child: icon),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
