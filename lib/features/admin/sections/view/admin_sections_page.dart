// lib/features/admin/sections/view/admin_sections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/icon_registry.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/section_entity.dart';
import '../cubit/admin_sections_cubit.dart';
import '../cubit/admin_sections_state.dart';

class AdminSectionsPage extends StatelessWidget {
  const AdminSectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminSectionsCubit, AdminSectionsState>(
      listener: (context, state) {
        if (state is AdminSectionsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
          // Reload after error shown to restore list
          if (state.message.contains('حذف')) {
            context.read<AdminSectionsCubit>().load();
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الأقسام العلمية'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<AdminSectionsCubit>().load(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/admin/sections/new');
              if (context.mounted) {
                context.read<AdminSectionsCubit>().load();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('قسم جديد'),
          ),
          body: switch (state) {
            AdminSectionsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            AdminSectionsError() => ErrorState(
                message: state.message,
                onRetry: () => context.read<AdminSectionsCubit>().load(),
              ),
            AdminSectionsLoaded() when state.sections.isEmpty => EmptyState(
                icon: Icons.category_outlined,
                message: 'لا توجد أقسام بعد',
                actionLabel: 'إضافة قسم',
                onAction: () async {
                  await context.push('/admin/sections/new');
                  if (context.mounted) {
                    context.read<AdminSectionsCubit>().load();
                  }
                },
              ),
            AdminSectionsLoaded() => RefreshIndicator(
                onRefresh: () =>
                    context.read<AdminSectionsCubit>().load(),
                child: ListView.builder(
                  padding:
                      const EdgeInsetsDirectional.all(AppSpacing.md),
                  itemCount: state.sections.length,
                  itemBuilder: (context, i) =>
                      _SectionListItem(section: state.sections[i]),
                ),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _SectionListItem extends StatelessWidget {
  final SectionEntity section;
  const _SectionListItem({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            SectionIcons.fromKey(section.icon),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(section.name),
        subtitle: Text(
          '${section.bookCount} ${section.bookCount == 1 ? 'كتاب' : 'كتب'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(
                  '/admin/sections/${section.id}/edit',
                  extra: section,
                );
                if (context.mounted) {
                  context.read<AdminSectionsCubit>().load();
                }
              },
              tooltip: 'تعديل',
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, section),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SectionEntity section) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text(
          'هل تريد حذف قسم "${section.name}"؟\n\n'
          'لا يمكن حذف القسم إذا كانت تحته كتب مرتبطة به.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context
                  .read<AdminSectionsCubit>()
                  .deleteSection(section.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
