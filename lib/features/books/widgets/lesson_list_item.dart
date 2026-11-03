// lib/features/books/widgets/lesson_list_item.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/lesson_with_progress_entity.dart';

class LessonListItem extends StatelessWidget {
  final LessonWithProgressEntity item;
  final bool isEnrolled;
  final bool isLocked;

  /// Lesson 1 is open to everyone (guests / unenrolled included). When true the
  /// item renders as accessible even without enrollment, with a free-preview hint.
  final bool isOpenToAll;
  final VoidCallback onTap;

  const LessonListItem({
    super.key,
    required this.item,
    required this.isEnrolled,
    required this.onTap,
    this.isLocked = false,
    this.isOpenToAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.isCompleted;
    final accessible = isEnrolled || isOpenToAll;
    final isDimmed = !accessible || isLocked;
    final isFreePreview = isOpenToAll && !isEnrolled;

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
            _LessonStatusIcon(
              isCompleted: isCompleted,
              accessible: accessible,
              isLocked: isLocked,
              orderIndex: item.lesson.orderIndex,
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.lesson.title,
                    style: AppTextStyles.small.copyWith(
                      color: isDimmed ? AppColors.inkFaint : AppColors.ink,
                      height: 1.5,
                    ),
                  ),
                  if (isFreePreview) ...[
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'درس تجريبي — متاح للجميع',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 0,
                      ),
                    ),
                  ] else if (!accessible) ...[
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'يجب التسجيل في الكتاب أولاً',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkFaint,
                        letterSpacing: 0,
                      ),
                    ),
                  ] else if (isLocked) ...[
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'أتمم المحاضرة السابقة أولاً',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkFaint,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  // Admin-entered playtime (migration 0015). Shown only for the
                  // media a lesson actually has a duration for; hidden entirely
                  // when neither is set, so no empty row is left behind.
                  if (item.lesson.videoDurationMinutes != null ||
                      item.lesson.audioDurationMinutes != null) ...[
                    const SizedBox(height: AppSpacing.s1),
                    _DurationTag(
                      videoMinutes: item.lesson.videoDurationMinutes,
                      audioMinutes: item.lesson.audioDurationMinutes,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            _MediaIcons(item: item),
          ],
        ),
      ),
    );
  }
}

class _LessonStatusIcon extends StatelessWidget {
  final bool isCompleted;
  final bool accessible;
  final bool isLocked;
  final int orderIndex;

  const _LessonStatusIcon({
    required this.isCompleted,
    required this.accessible,
    required this.isLocked,
    required this.orderIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (!accessible || isLocked) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.paperSunk,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.lock_outline,
          size: 14,
          color: AppColors.inkFaint,
        ),
      );
    }
    if (isCompleted) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
        child: const Icon(Icons.check, size: 16, color: AppColors.inkInvert),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.paperSunk,
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          '$orderIndex',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MediaIcons extends StatelessWidget {
  final LessonWithProgressEntity item;

  const _MediaIcons({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.hasVideo)
          const Icon(
            Icons.play_circle_outline,
            size: 16,
            color: AppColors.inkFaint,
          ),
        if (item.hasAudio)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: AppSpacing.s1),
            child: Icon(
              Icons.headphones_outlined,
              size: 16,
              color: AppColors.inkFaint,
            ),
          ),
        if (item.hasPdf)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: AppSpacing.s1),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 16,
              color: AppColors.inkFaint,
            ),
          ),
      ],
    );
  }
}

/// Small per-medium playtime tag (e.g. video 15 د · audio 12 د). Uses the same
/// media icons + faint caption tokens as [_MediaIcons]; [Wrap] lets the two
/// chips flow to a second line on narrow screens instead of overflowing.
class _DurationTag extends StatelessWidget {
  final int? videoMinutes;
  final int? audioMinutes;

  const _DurationTag({required this.videoMinutes, required this.audioMinutes});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s3,
      runSpacing: AppSpacing.s1,
      children: [
        if (videoMinutes != null)
          _DurationChip(
            icon: Icons.play_circle_outline,
            minutes: videoMinutes!,
          ),
        if (audioMinutes != null)
          _DurationChip(
            icon: Icons.headphones_outlined,
            minutes: audioMinutes!,
          ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  final IconData icon;
  final int minutes;

  const _DurationChip({required this.icon, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkFaint),
        const SizedBox(width: AppSpacing.s1),
        // Western digits to match the lesson-number convention on this card.
        Text(
          '$minutes د',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkFaint,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
