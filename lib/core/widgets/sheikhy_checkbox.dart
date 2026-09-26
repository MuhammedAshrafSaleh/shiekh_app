// lib/core/widgets/sheikhy_checkbox.dart
//
// NEW (redesign — Auth Phase 1). Heritage square checkbox + label row, used by
// Login "remember me" and Create "accept terms". Checked = primary box with a
// gold check; unchecked = sunk paper with a border. The [label] is a Widget so
// callers can pass rich text (e.g. an inline link). Spec: DESIGN_SYSTEM.md §5.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class SheikhyCheckbox extends StatelessWidget {
  const SheikhyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: AppRadii.rSm,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.s1),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.paperSunk,
                borderRadius: AppRadii.rSm,
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 15, color: AppColors.goldLight)
                  : null,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(child: label),
          ],
        ),
      ),
    );
  }
}
