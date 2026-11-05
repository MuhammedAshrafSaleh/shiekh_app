// lib/features/admin/suggestions/view/admin_suggestions_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/suggestion_entity.dart';
import '../cubit/admin_suggestion_cubit.dart';
import '../cubit/admin_suggestion_state.dart';

class AdminSuggestionsPage extends StatelessWidget {
  const AdminSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminSuggestionCubit, AdminSuggestionState>(
      listener: (context, state) {
        if (state is AdminSuggestionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          context.read<AdminSuggestionCubit>().load();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة المقترحات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<AdminSuggestionCubit>().load(),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/admin/suggestions/new');
              if (context.mounted) {
                context.read<AdminSuggestionCubit>().load();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('مقترح جديد'),
          ),
          body: switch (state) {
            AdminSuggestionLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            AdminSuggestionError() => ErrorState(
              message: state.message,
              onRetry: () => context.read<AdminSuggestionCubit>().load(),
            ),
            AdminSuggestionLoaded() when state.suggestions.isEmpty =>
              EmptyState(
                icon: Icons.recommend_outlined,
                message: 'لا توجد مقترحات بعد',
                actionLabel: 'إضافة مقترح',
                onAction: () async {
                  await context.push('/admin/suggestions/new');
                  if (context.mounted) {
                    context.read<AdminSuggestionCubit>().load();
                  }
                },
              ),
            AdminSuggestionLoaded() => RefreshIndicator(
              onRefresh: () => context.read<AdminSuggestionCubit>().load(),
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                itemCount: state.suggestions.length,
                itemBuilder: (context, i) => _SuggestionListItem(
                  key: ValueKey(state.suggestions[i].id),
                  suggestion: state.suggestions[i],
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _SuggestionListItem extends StatelessWidget {
  final SuggestionEntity suggestion;

  const _SuggestionListItem({required super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: suggestion.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_outlined),
            ),
          ),
        ),
        title: Text(
          suggestion.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  suggestion.isActive ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: suggestion.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  suggestion.isActive ? 'نشط' : 'مخفي',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: suggestion.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'الترتيب: ${suggestion.sortOrder ?? '—'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  suggestion.isVideo
                      ? Icons.play_circle_outline
                      : Icons.headphones,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  suggestion.isVideo ? 'فيديو' : 'صوتي',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  suggestion.formattedDuration,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(
                  '/admin/suggestions/${suggestion.id}/edit',
                  extra: suggestion,
                );
                if (context.mounted) {
                  context.read<AdminSuggestionCubit>().load();
                }
              },
              tooltip: 'تعديل',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف المقترح'),
        content: Text('هل تريد حذف مقترح "${suggestion.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AdminSuggestionCubit>().deleteSuggestion(
                suggestion.id,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
