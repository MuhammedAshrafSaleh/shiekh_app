// lib/features/path/widgets/book_progress_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../models/book_with_progress_entity.dart';

class BookProgressCard extends StatelessWidget {
  final BookWithProgressEntity item;

  const BookProgressCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (item.progress * 100).toInt();
    final isAvailable = item.book.status == 'published';

    // CC-2: unpublished enrolled book → show card but with unavailable overlay;
    // enrollment row persists, user is just informed it's temporarily unavailable.
    return Card(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isAvailable
                ? () => context.go('/books/${item.book.id}')
                : null,
            child: Opacity(
              opacity: isAvailable ? 1.0 : 0.45,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 80,
                        child: item.book.coverImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: item.book.coverImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => _ThumbnailPlaceholder(
                                  title: item.book.title,
                                  theme: theme,
                                ),
                                errorWidget: (_, _, _) => _ThumbnailPlaceholder(
                                  title: item.book.title,
                                  theme: theme,
                                ),
                              )
                            : _ThumbnailPlaceholder(
                                title: item.book.title,
                                theme: theme,
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.book.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$progressPercent٪',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
          ),
          // CC-2: show unavailable badge when book has been unpublished
          if (!isAvailable)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'غير متاح حاليًا',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _ThumbnailPlaceholder({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0] : '؟',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
