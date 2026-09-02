// lib/features/sections/widgets/section_grid_item.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/section_entity.dart';

class SectionGridItem extends StatelessWidget {
  const SectionGridItem({super.key, required this.section});

  final SectionEntity section;

  String _toArabicNumerals(int n) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = western.indexOf(c);
      return i >= 0 ? arabic[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final icon = SectionIcons.fromKey(section.icon);

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.rLg,
          onTap: () => context.push(
            '/sections/${section.id}?name=${Uri.encodeComponent(section.name)}',
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: AppColors.goldDeep),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  section.name,
                  style: AppTextStyles.buttonLabel.copyWith(
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${_toArabicNumerals(section.bookCount)} كتاب',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
