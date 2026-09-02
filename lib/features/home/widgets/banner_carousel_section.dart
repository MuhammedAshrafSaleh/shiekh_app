// lib/features/home/widgets/banner_carousel_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/girih_background.dart';
import '../../../core/widgets/sheikhy_badge.dart';
import '../../../models/banner_entity.dart';

class BannerCarouselSection extends StatefulWidget {
  const BannerCarouselSection({
    super.key,
    required this.banners,
    required this.onTap,
  });

  final List<BannerEntity> banners;
  final void Function(BannerEntity) onTap;

  @override
  State<BannerCarouselSection> createState() => _BannerCarouselSectionState();
}

class _BannerCarouselSectionState extends State<BannerCarouselSection> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselSlider.builder(
          itemCount: widget.banners.length,
          itemBuilder: (context, index, _) {
            final banner = widget.banners[index];
            return _BannerItem(
              banner: banner,
              onTap: () => widget.onTap(banner),
            );
          },
          options: CarouselOptions(
            height: 180,
            viewportFraction: 1.0,
            autoPlay: widget.banners.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (index, _) =>
                setState(() => _currentIndex = index),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: AppSpacing.s3),
          _PageDots(
            count: widget.banners.length,
            current: _currentIndex,
          ),
        ],
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({required this.banner, required this.onTap});

  final BannerEntity banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.pageGutter,
        ),
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
        child: banner.imageUrl != null
            ? _ImageBanner(banner: banner)
            : _PlaceholderBanner(banner: banner),
      ),
    );
  }
}

class _ImageBanner extends StatelessWidget {
  const _ImageBanner({required this.banner});

  final BannerEntity banner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: banner.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ColoredBox(color: AppColors.paperSunk),
          errorWidget: (_, _, _) => const ColoredBox(color: AppColors.paperSunk),
        ),
        // gradient overlay for text legibility
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              colors: [Colors.transparent, Color(0xCC14291F)],
              stops: [0.4, 1.0],
            ),
          ),
        ),
        if (banner.linkedBookId != null)
          PositionedDirectional(
            top: AppSpacing.s4,
            start: AppSpacing.s4,
            child: const SheikhyBadge(
              variant: SheikhyBadgeVariant.isNew,
              label: 'دورة جديدة',
            ),
          ),
        PositionedDirectional(
          start: AppSpacing.s4,
          end: AppSpacing.s4,
          bottom: AppSpacing.s4,
          child: Text(
            banner.title,
            style: AppTextStyles.h3.copyWith(color: AppColors.inkInvert),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner({required this.banner});

  final BannerEntity banner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.paperSunk),
        GirihBackground(color: AppColors.primary, opacity: 0.09),
        if (banner.linkedBookId != null)
          PositionedDirectional(
            top: AppSpacing.s4,
            start: AppSpacing.s4,
            child: const SheikhyBadge(
              variant: SheikhyBadgeVariant.isNew,
              label: 'دورة جديدة',
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s5,
            ),
            child: Text(
              banner.title,
              style: AppTextStyles.h3.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: AppRadii.rPill,
          ),
        );
      }),
    );
  }
}
