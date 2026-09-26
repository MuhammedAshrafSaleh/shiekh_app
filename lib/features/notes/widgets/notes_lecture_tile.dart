// lib/features/notes/widgets/notes_lecture_tile.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class NotesLectureTile extends StatelessWidget {
  final String title;
  final int noteCount;
  final VoidCallback onTap;

  const NotesLectureTile({
    super.key,
    required this.title,
    required this.noteCount,
    required this.onTap,
  });

  String get _countLabel {
    if (noteCount == 1) return 'ملحوظة واحدة';
    if (noteCount == 2) return 'ملحوظتان';
    return '$noteCount ملحوظات';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.pageGutter,
          vertical: AppSpacing.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint,
              ),
              child: Icon(
                Icons.notes_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.small.copyWith(color: AppColors.ink, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    _countLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Icon(
              Icons.arrow_back_ios,
              size: 14,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
