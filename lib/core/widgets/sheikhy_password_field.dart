// lib/core/widgets/sheikhy_password_field.dart
//
// NEW (redesign — Auth Phase 1). A password field mirroring SheikhyTextField's
// heritage look (same AppDecorations.field* tokens) but adding a trailing
// eye-toggle — SheikhyTextField exposes only a prefixIcon and may not be
// modified, so this is a separate composed widget (not a styling duplicate).
// Supports an optional [trailingIndicator] (e.g. the confirm-field match check).
// Spec: DESIGN_SYSTEM.md §5/§7.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhyPasswordField extends StatefulWidget {
  const SheikhyPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon = const Icon(Icons.lock_outline),
    this.trailingIndicator,
    this.enabled = true,
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

  /// Optional indicator shown just before the eye toggle (e.g. a green check
  /// when a confirm-password matches).
  final Widget? trailingIndicator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SheikhyPasswordField> createState() => _SheikhyPasswordFieldState();
}

class _SheikhyPasswordFieldState extends State<SheikhyPasswordField> {
  final FocusNode _focusNode = FocusNode();
  // Local view state only (no bloc): drives the field rebuild without setState.
  final ValueNotifier<bool> _obscured = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _focusNode.dispose();
    _obscured.dispose();
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
          animation: Listenable.merge([_focusNode, _obscured]),
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
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      child: Row(
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
              obscureText: _obscured.value,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: AppTextStyles.body.copyWith(
                color: widget.enabled ? AppColors.ink : AppColors.inkFaint,
              ),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                // Theme-independent: the heritage container owns the fill, so
                // never inherit a fill/border from an ambient inputDecorationTheme.
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ),
          if (widget.trailingIndicator != null) ...[
            const SizedBox(width: AppSpacing.s2),
            widget.trailingIndicator!,
          ],
          _ToggleButton(
            obscured: _obscured.value,
            onTap: widget.enabled
                ? () => _obscured.value = !_obscured.value
                : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: AppColors.inkFaint,
        ),
      ),
    );
  }
}
