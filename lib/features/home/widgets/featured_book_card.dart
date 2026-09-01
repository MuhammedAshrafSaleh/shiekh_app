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
    final percent = (item.progress.clamp(0.0, 1.0) * 100).round();
    final started = item.completedLessons > 0;
    final statusLabel = started ? 'مكتمل' : 'لم يبدأ بعد';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.book.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          '${item.totalLessons} درس',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.play_circle_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Text(
                          '$percent%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          statusLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ProgressBar(value: item.progress),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 88,
                  height: 112,
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
