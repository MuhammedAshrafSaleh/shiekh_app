// lib/features/home/widgets/featured_book_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../models/book_with_progress_entity.dart';

class FeaturedBookCard extends StatelessWidget {
  final BookWithProgressEntity item;
  final VoidCallback onTap;

  const FeaturedBookCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 180,
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: item.book.coverImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.book.coverImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _CoverPlaceholder(
                            title: item.book.title,
                            theme: theme,
                          ),
                          errorWidget: (_, _, _) => _CoverPlaceholder(
                            title: item.book.title,
                            theme: theme,
                          ),
                        )
                      : _CoverPlaceholder(
                          title: item.book.title,
                          theme: theme,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.book.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ProgressBar(value: item.progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _CoverPlaceholder({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0] : '؟',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
