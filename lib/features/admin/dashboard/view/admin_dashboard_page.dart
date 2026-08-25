// lib/features/admin/dashboard/view/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/book_entity.dart';
import '../cubit/admin_dashboard_cubit.dart';
import '../cubit/admin_dashboard_state.dart';
import '../data/admin_dashboard_repository.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminDashboardCubit, AdminDashboardState>(
      listener: (context, state) {
        if (state is AdminDashboardError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة التحكم'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<AdminDashboardCubit>().load(),
              ),
            ],
          ),
          body: switch (state) {
            AdminDashboardLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            AdminDashboardError() => ErrorState(
                message: state.message,
                onRetry: () => context.read<AdminDashboardCubit>().load(),
              ),
            AdminDashboardLoaded() => _LoadedBody(
                stats: state.stats,
                books: state.books,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _LoadedBody extends StatelessWidget {
  final AdminStats stats;
  final List<BookEntity> books;

  const _LoadedBody({required this.stats, required this.books});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<AdminDashboardCubit>().load(),
      child: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        children: [
          _StatsRow(stats: stats),
          const SizedBox(height: AppSpacing.lg),
          _QuickActions(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'كتبي',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (books.isEmpty)
            EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'لا توجد كتب بعد',
              actionLabel: 'إضافة كتاب',
              onAction: () => context.push('/admin/books/new'),
            )
          else
            ...books.map((b) => _BookListItem(book: b)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AdminStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'الكتب',
          value: stats.totalBooks.toString(),
          icon: Icons.menu_book_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          label: 'الطلاب',
          value: stats.totalStudents.toString(),
          icon: Icons.people_outline,
          color: AppColors.gold,
        ),
        _StatCard(
          label: 'الدروس',
          value: stats.totalLessons.toString(),
          icon: Icons.play_circle_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          label: 'أسئلة جديدة',
          value: stats.pendingQa.toString(),
          icon: Icons.question_answer_outlined,
          color: stats.pendingQa > 0 ? Colors.orange : AppColors.gold,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_box_outlined,
                label: 'كتاب جديد',
                onTap: () => context.push('/admin/books/new'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.category_outlined,
                label: 'إدارة الأقسام',
                onTap: () => context.push('/admin/sections'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.view_carousel_outlined,
                label: 'إدارة البانرات',
                onTap: () => context.push('/admin/banners'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.notifications_outlined,
                label: 'الإشعارات',
                onTap: () => context.push('/admin/notifications'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final BookEntity book;
  const _BookListItem({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(
          book.title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.xs,
            children: [
              StatusBadge(
                status: book.status == 'published'
                    ? BadgeStatus.published
                    : BadgeStatus.draft,
              ),
              StatusBadge(
                status: book.reviewStatus == 'completed'
                    ? BadgeStatus.completed
                    : BadgeStatus.inReview,
              ),
              if (book.isFeatured)
                const StatusBadge(status: BadgeStatus.published),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/admin/books/${book.id}/edit'),
              tooltip: 'تعديل',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, book),
              tooltip: 'حذف',
            ),
          ],
        ),
        onTap: () => context.push(
          '/admin/books/${book.id}/lessons?title=${Uri.encodeComponent(book.title)}',
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, BookEntity book) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف كتاب "${book.title}"؟\n\n'
          'سيتم حذف جميع الدروس والبيانات المرتبطة بشكل نهائي ولا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AdminDashboardCubit>().deleteBook(book.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
  }
}
