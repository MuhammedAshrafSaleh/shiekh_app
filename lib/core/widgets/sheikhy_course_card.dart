// lib/core/widgets/sheikhy_course_card.dart
//
// Course card with a mihrab-arch head over a patterned primary banner, then a
// white body (title / meta / optional progress / footer with CTA).
// Spec: DESIGN_SYSTEM.md §5 + HTML reference course card.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'girih_background.dart';
import 'mihrab_arch.dart';
import 'sheikhy_progress_bar.dart';

class SheikhyCourseCard extends StatelessWidget {
  const SheikhyCourseCard({
    super.key,
    required this.title,
    required this.meta,
    this.badges = const [],
    this.progress,
    this.footerText,
    this.ctaText,
    this.onTap,
    this.headerHeight = 150,
  });

  final String title;
  final String meta;

  /// Chips shown at the top of the banner (e.g. "فيديو", "مستوى ٢").
  final List<Widget> badges;

  /// 0.0–1.0; when non-null a progress bar is shown above the footer.
  final double? progress;
  final String? footerText;
  final String? ctaText;
  final VoidCallback? onTap;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: AppRadii.rLg,
      child: Container(
        decoration: AppDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_header(), _body()],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: AppRadii.rLg, onTap: onTap, child: card),
    );
  }

  Widget _header() {
    return ClipRect(
      child: SizedBox(
        height: headerHeight,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: AppColors.primary)),
            // arabesque pattern
            Positioned.fill(
              child: CustomPaint(
                painter: ArabesquePainter(
                  color: AppColors.goldLight,
                  opacity: 0.16,
                ),
              ),
            ),
            // mihrab arch, bottom-end corner (bleeds off the bottom edge)
            const PositionedDirectional(
              bottom: -28,
              end: 24,
              child: MihrabArch(width: 112, height: 126),
            ),
            // badges
            if (badges.isNotEmpty)
              PositionedDirectional(
                top: AppSpacing.s4,
                end: 20,
                child: Wrap(spacing: AppSpacing.s2, children: badges),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final hasFooter = footerText != null || ctaText != null;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.s2),
          Text(meta, style: AppTextStyles.small),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.s4),
            SheikhyProgressBar(value: progress!),
          ],
          if (hasFooter) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.s4),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (footerText != null)
                    Expanded(
                      child: Text(footerText!, style: AppTextStyles.small),
                    ),
                  if (ctaText != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaText!,
                          style: AppTextStyles.buttonLabel.copyWith(
                            fontSize: 15,
                            color: AppColors.goldDeep,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s1),
                        const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: AppColors.goldDeep,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
