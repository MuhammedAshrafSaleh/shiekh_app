// lib/core/widgets/sheikhy_horizontal_book_card.dart
//
// Heritage horizontal book card: cover thumbnail (start) | meta column (end).
// Used in home featured-books list and anywhere a compact horizontal card is needed.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'girih_background.dart';
import 'sheikhy_badge.dart';
import 'sheikhy_progress_bar.dart';

class SheikhyHorizontalBookCard extends StatelessWidget {
  const SheikhyHorizontalBookCard({
    super.key,
    required this.title,
    required this.totalLessons,
    required this.completedLessons,
    required this.progress,
    required this.onTap,
    this.coverImageUrl,
    this.isEnrolled = false,
  });

  final String title;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final VoidCallback onTap;
  final String? coverImageUrl;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.rLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cover(title: title, imageUrl: coverImageUrl),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: _InfoColumn(
                    title: title,
                    totalLessons: totalLessons,
                    completedLessons: completedLessons,
                    progress: progress,
                    isEnrolled: isEnrolled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.rMd,
      child: SizedBox(
        width: 80,
        height: 104,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _Placeholder(title: title),
                errorWidget: (_, _, _) => _Placeholder(title: title),
              )
            : _Placeholder(title: title),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.paperSunk),
        GirihBackground(color: AppColors.primary, opacity: 0.09),
        Center(
          child: Text(
            title.isNotEmpty ? title.characters.first : '؟',
            style: GoogleFonts.arefRuqaa(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.title,
    required this.totalLessons,
    required this.completedLessons,
    required this.progress,
    required this.isEnrolled,
  });

  final String title;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final bool isEnrolled;

  SheikhyBadge get _statusBadge {
    if (totalLessons > 0 && completedLessons >= totalLessons) {
      return const SheikhyBadge(
        variant: SheikhyBadgeVariant.passed,
        label: 'مكتمل',
      );
    }
    if (completedLessons > 0) {
      return const SheikhyBadge(
        variant: SheikhyBadgeVariant.isNew,
        label: 'جارٍ',
      );
    }
    if (isEnrolled) {
      return const SheikhyBadge(
        variant: SheikhyBadgeVariant.isNew,
        label: 'مسجّل',
      );
    }
    return const SheikhyBadge(
      variant: SheikhyBadgeVariant.draft,
      label: 'لم يبدأ',
    );
  }

  String get _progressLabel {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return '٪$pct';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusBadge,
        const SizedBox(height: AppSpacing.s2),
        Text(
          title,
          style: AppTextStyles.small.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 13,
              color: AppColors.inkFaint,
            ),
            const SizedBox(width: AppSpacing.s1),
            Text(
              '$totalLessons درساً',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.inkFaint,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          _progressLabel,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkMuted,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        SheikhyProgressBar(value: progress),
      ],
    );
  }
}
