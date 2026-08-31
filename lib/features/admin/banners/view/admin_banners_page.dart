// lib/features/admin/banners/view/admin_banners_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/banner_entity.dart';
import '../cubit/admin_banner_cubit.dart';
import '../cubit/admin_banner_state.dart';

class AdminBannersPage extends StatelessWidget {
  const AdminBannersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminBannerCubit, AdminBannerState>(
      listener: (context, state) {
        if (state is AdminBannerError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
          context.read<AdminBannerCubit>().load();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة البانرات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<AdminBannerCubit>().load(),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final loaded =
                  state is AdminBannerLoaded ? state : null;
              await context.push(
                '/admin/banners/new',
                extra: loaded?.books ?? [],
              );
              if (context.mounted) {
                context.read<AdminBannerCubit>().load();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('بانر جديد'),
          ),
          body: switch (state) {
            AdminBannerLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            AdminBannerError() => ErrorState(
                message: state.message,
                onRetry: () => context.read<AdminBannerCubit>().load(),
              ),
            AdminBannerLoaded() when state.banners.isEmpty => EmptyState(
                icon: Icons.view_carousel_outlined,
                message: 'لا توجد بانرات بعد',
                actionLabel: 'إضافة بانر',
                onAction: () async {
                  await context.push(
                    '/admin/banners/new',
                    extra: state.books,
                  );
                  if (context.mounted) {
                    context.read<AdminBannerCubit>().load();
                  }
                },
              ),
            AdminBannerLoaded() => RefreshIndicator(
                onRefresh: () =>
                    context.read<AdminBannerCubit>().load(),
                child: ListView.builder(
                  padding:
                      const EdgeInsetsDirectional.all(AppSpacing.md),
                  itemCount: state.banners.length,
                  itemBuilder: (context, i) => _BannerListItem(
                    key: ValueKey(state.banners[i].id),
                    banner: state.banners[i],
                    books: state.books,
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

class _BannerListItem extends StatelessWidget {
  final BannerEntity banner;
  final List books;

  const _BannerListItem({
    required super.key,
    required this.banner,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: banner.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined),
              ),
        title: Text(
          banner.title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  banner.isActive ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: banner.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  banner.isActive ? 'نشط' : 'مخفي',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: banner.isActive ? Colors.green : Colors.grey,
                      ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'الترتيب: ${banner.orderIndex}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (banner.linkedBookId != null)
              Text(
                'مرتبط بكتاب',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (banner.externalLink != null)
              Text(
                'رابط خارجي',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                'بدون رابط',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  '/admin/banners/${banner.id}/edit',
                  extra: {'banner': banner, 'books': books},
                );
                if (context.mounted) {
                  context.read<AdminBannerCubit>().load();
                }
              },
              tooltip: 'تعديل',
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red),
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
        title: const Text('حذف البانر'),
        content: Text('هل تريد حذف بانر "${banner.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AdminBannerCubit>().deleteBanner(banner.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
