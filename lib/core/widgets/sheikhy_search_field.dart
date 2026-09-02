// lib/core/widgets/sheikhy_search_field.dart
//
// Heritage search input: white surface, gold focus border, search icon prefix.
// No label overhead — use for filtering/searching inside list screens.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SheikhySearchField extends StatelessWidget {
  const SheikhySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'بحث...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body.copyWith(color: AppColors.ink, height: 1.2),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(
          color: AppColors.inkFaint,
          height: 1.2,
        ),
        prefixIcon: const Icon(
          Icons.search_outlined,
          color: AppColors.inkFaint,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.rLg,
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.rLg,
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.rLg,
          borderSide: const BorderSide(
            color: AppColors.gold,
            width: AppBorders.control,
          ),
        ),
      ),
    );
  }
}
