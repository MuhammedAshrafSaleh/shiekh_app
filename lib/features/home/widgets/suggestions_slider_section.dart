// lib/features/home/widgets/suggestions_slider_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/suggestion_entity.dart';
import 'home_slider_config.dart';

/// The "مقترحات" home section: a horizontal, auto-scrolling slider of curated
/// media cards. Mirrors [BannerCarouselSection] but uses a card-style viewport
/// (multiple cards peeking) and a slightly faster auto-scroll cadence.
class SuggestionsSliderSection extends StatelessWidget {
  const SuggestionsSliderSection({
    super.key,
    required this.suggestions,
    required this.onTap,
  });

  final List<SuggestionEntity> suggestions;
  final void Function(SuggestionEntity) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.pageGutter,
            AppSpacing.s4,
            AppSpacing.pageGutter,
            AppSpacing.s3,
          ),
          child: Text('مقترحات', style: AppTextStyles.h3),
        ),
        CarouselSlider.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index, _) {
            return _SuggestionCard(
              suggestion: suggestions[index],
              onTap: () => onTap(suggestions[index]),
            );
          },
          options: CarouselOptions(
            height: 208,
            viewportFraction: 0.72,
            enableInfiniteScroll: suggestions.length > 1,
            autoPlay: suggestions.length > 1,
            autoPlayInterval: kSuggestionsAutoScrollInterval,
            padEnds: false,
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final SuggestionEntity suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: AppSpacing.pageGutter),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: AppRadii.rLg,
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: suggestion.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.paperSunk),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: AppColors.paperSunk),
                  ),
                  PositionedDirectional(
                    top: AppSpacing.s3,
                    start: AppSpacing.s3,
                    child: _TypeBadge(suggestion: suggestion),
                  ),
                  PositionedDirectional(
                    bottom: AppSpacing.s3,
                    end: AppSpacing.s3,
                    child: _DurationChip(text: suggestion.formattedDuration),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.s3),
              child: Text(
                suggestion.title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.suggestion});

  final SuggestionEntity suggestion;

  @override
  Widget build(BuildContext context) {
    final isVideo = suggestion.isVideo;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.92),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_circle_outline : Icons.headphones,
            size: 14,
            color: AppColors.inkInvert,
          ),
          const SizedBox(width: AppSpacing.s1),
          Text(
            isVideo ? 'فيديو' : 'صوتي',
            style: AppTextStyles.small.copyWith(color: AppColors.inkInvert),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC14291F),
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: AppTextStyles.small.copyWith(color: AppColors.inkInvert),
      ),
    );
  }
}
