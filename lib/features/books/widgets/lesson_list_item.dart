// lib/features/books/widgets/lesson_list_item.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/lesson_with_progress_entity.dart';

class LessonListItem extends StatelessWidget {
  final LessonWithProgressEntity item;
  final bool isEnrolled;
  final VoidCallback onTap;

  const LessonListItem({
    super.key,
    required this.item,
    required this.isEnrolled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = item.isCompleted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            _LessonStatusIcon(
              isCompleted: isCompleted,
              isEnrolled: isEnrolled,
              orderIndex: item.lesson.orderIndex,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.lesson.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isEnrolled
                          ? null
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (!isEnrolled)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.xs),
                      child: Text(
                        'يجب التسجيل في الكتاب أولاً',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _MediaIcons(lesson: item.lesson),
          ],
        ),
      ),
    );
  }
}

class _LessonStatusIcon extends StatelessWidget {
  final bool isCompleted;
  final bool isEnrolled;
  final int orderIndex;
  final ColorScheme colorScheme;

  const _LessonStatusIcon({
    required this.isCompleted,
    required this.isEnrolled,
    required this.orderIndex,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnrolled) {
      return Icon(
        Icons.lock_outline,
        color: colorScheme.onSurface.withValues(alpha: 0.35),
        size: 22,
      );
    }
    if (isCompleted) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: Text(
        '$orderIndex',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _MediaIcons extends StatelessWidget {
  final dynamic lesson;

  const _MediaIcons({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lesson.hasVideo)
          Icon(Icons.play_circle_outline, size: 16, color: color),
        if (lesson.hasAudio)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Icon(Icons.headphones_outlined, size: 16, color: color),
          ),
        if (lesson.hasPdf)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Icon(Icons.picture_as_pdf_outlined,
                size: 16, color: color),
          ),
      ],
    );
  }
}
