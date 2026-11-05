// lib/core/widgets/sheikhy_text_field.dart
//
// Heritage text field: label above, sunk field, gold focus border, helper/error
// below. Error state (danger border + pink bg) is mandatory from the Auth
// screens onward. Spec: DESIGN_SYSTEM.md §5 / §7.
//
// The [controller] is owned by the caller (declared in its State, disposed
// there). The FocusNode is owned internally and drives the focus styling via a
// Listenable rebuild (no setState needed).
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhyTextField extends StatefulWidget {
  const SheikhyTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SheikhyTextField> createState() => _SheikhyTextFieldState();
}

class _SheikhyTextFieldState extends State<SheikhyTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasError => widget.errorText != null;

  @override
  Widget build(BuildContext context) {
    final labelColor = !widget.enabled
        ? AppColors.inkFaint
        : (_hasError ? AppColors.danger : AppColors.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.fieldLabel.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.s2),
        AnimatedBuilder(
          animation: _focusNode,
          builder: (context, _) => _field(),
        ),
        if (widget.errorText != null || widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            widget.errorText ?? widget.helperText!,
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 0,
              color: _hasError ? AppColors.danger : AppColors.inkFaint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _field() {
    final BoxDecoration decoration;
    if (!widget.enabled) {
      decoration = AppDecorations.field.copyWith(color: AppColors.paperSunk);
    } else if (_hasError) {
      decoration = AppDecorations.fieldError;
    } else if (_focusNode.hasFocus) {
      decoration = AppDecorations.fieldFocused;
    } else {
      decoration = AppDecorations.field;
    }

    return Container(
      height: 48,
      decoration: decoration,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.prefixIcon != null) ...[
            IconTheme(
              data: const IconThemeData(color: AppColors.inkFaint, size: 18),
              child: widget.prefixIcon!,
            ),
            const SizedBox(width: AppSpacing.s2 + 2),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              strutStyle: const StrutStyle(
                fontFamily: 'Tajawal',
                fontSize: 17,
                height: 1.5,
                leadingDistribution: TextLeadingDistribution.even,
                forceStrutHeight: true,
              ),
              style: AppTextStyles.inputText.copyWith(
                color: widget.enabled ? AppColors.ink : AppColors.inkFaint,
              ),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: AppTextStyles.inputText.copyWith(
                  color: AppColors.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
