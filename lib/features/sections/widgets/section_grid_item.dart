// lib/features/sections/widgets/section_grid_item.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/icon_registry.dart';
import '../../../models/section_entity.dart';

class SectionGridItem extends StatelessWidget {
  final SectionEntity section;

  const SectionGridItem({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = SectionIcons.fromKey(section.icon);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/sections/${section.id}'),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                section.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'كتاب ${section.bookCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
