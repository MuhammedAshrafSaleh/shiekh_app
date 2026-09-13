// lib/core/widgets/sheikhy_password_strength.dart
//
// NEW (redesign — Auth Phase 1). Segmented password-strength meter + hint line
// for the Create Account screen (2a/2b). Purely presentational: strength is
// derived from the current field value (view state only — no bloc/repo, no
// grading logic). Spec: DESIGN_SYSTEM.md §5/§7.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhyPasswordStrength extends StatelessWidget {
  const SheikhyPasswordStrength({
    super.key,
    required this.password,
    this.hintText,
  });

  final String password;
  final String? hintText;

  static const int _segments = 4;

  /// 0..4 — one point each for: length ≥ 8, a digit, a letter (Latin/Arabic),
  /// and length ≥ 12 or a symbol.
  int get _score {
    if (password.isEmpty) return 0;
    var s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[A-Za-zء-ي]').hasMatch(password)) s++;
    if (password.length >= 12 ||
        RegExp(r'[^A-Za-z0-9ء-ي]').hasMatch(password)) {
      s++;
    }
    return s.clamp(0, _segments);
  }

  Color _fillColor(int score) {
    if (score <= 1) return AppColors.danger;
    if (score == 2) return AppColors.warning;
    if (score == 3) return AppColors.gold;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final fill = _fillColor(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_segments, (i) {
            final active = i < score;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: i == _segments - 1 ? 0 : AppSpacing.s1,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? fill : AppColors.border,
                    borderRadius: AppRadii.rPill,
                  ),
                ),
              ),
            );
          }),
        ),
        if (hintText != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            hintText!,
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 0,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ],
    );
  }
}
