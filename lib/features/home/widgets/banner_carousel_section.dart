// lib/features/home/widgets/banner_carousel_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/banner_entity.dart';

class BannerCarouselSection extends StatelessWidget {
  final List<BannerEntity> banners;
  final void Function(BannerEntity) onTap;

  const BannerCarouselSection({
    super.key,
    required this.banners,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: banners.length,
      itemBuilder: (context, index, _) {
        final banner = banners[index];
        return _BannerItem(banner: banner, onTap: () => onTap(banner));
      },
      options: CarouselOptions(
        height: 180,
        viewportFraction: 0.92,
        enlargeCenterPage: true,
        autoPlay: banners.length > 1,
        autoPlayInterval: const Duration(seconds: 4),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final BannerEntity banner;
  final VoidCallback onTap;

  const _BannerItem({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: banner.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: banner.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, _) => _Placeholder(title: banner.title, theme: theme),
                errorWidget: (_, _, _) => _Placeholder(title: banner.title, theme: theme),
              )
            : _Placeholder(title: banner.title, theme: theme),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _Placeholder({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
