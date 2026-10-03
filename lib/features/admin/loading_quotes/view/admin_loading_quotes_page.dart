// lib/features/admin/loading_quotes/view/admin_loading_quotes_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/show_confirm_dialog.dart';
import '../../../../models/loading_quote_entity.dart';
import '../cubit/admin_loading_quotes_cubit.dart';
import '../cubit/admin_loading_quotes_state.dart';

class AdminLoadingQuotesPage extends StatelessWidget {
  const AdminLoadingQuotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نصوص شاشة التحميل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminLoadingQuotesCubit>().load(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addQuote(context),
        icon: const Icon(Icons.add),
        label: const Text('نص جديد'),
      ),
      body: BlocConsumer<AdminLoadingQuotesCubit, AdminLoadingQuotesState>(
        listenWhen: (prev, curr) =>
            curr is AdminLoadingQuotesLoaded &&
            (curr.transientSuccess != null || curr.transientError != null),
        listener: (context, state) {
          if (state is! AdminLoadingQuotesLoaded) return;
          final messenger = ScaffoldMessenger.of(context);
          if (state.transientSuccess != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientSuccess!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state.transientError != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientError!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            AdminLoadingQuotesLoading() || AdminLoadingQuotesInitial() =>
              const Center(child: CircularProgressIndicator()),
            AdminLoadingQuotesError(:final message) => ErrorState(
              message: message,
              onRetry: () => context.read<AdminLoadingQuotesCubit>().load(),
            ),
            AdminLoadingQuotesLoaded(:final quotes) when quotes.isEmpty =>
              EmptyState(
                icon: Icons.format_quote_outlined,
                message: 'لا توجد نصوص بعد',
                actionLabel: 'إضافة نص',
                onAction: () => _addQuote(context),
              ),
            AdminLoadingQuotesLoaded() => _LoadedView(state: state),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Future<void> _addQuote(BuildContext context) async {
    final cubit = context.read<AdminLoadingQuotesCubit>();
    await context.push('/admin/loading-quotes/new', extra: cubit.nextSortOrder);
    if (context.mounted) cubit.load();
  }
}

class _LoadedView extends StatelessWidget {
  final AdminLoadingQuotesLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminLoadingQuotesCubit>();
    return Column(
      children: [
        if (!state.hasActive)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'لا توجد نصوص مفعّلة — سيتم عرض النصوص الافتراضية للطلاب.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.quotes.length,
            onReorder: cubit.reorder,
            itemBuilder: (context, index) => _QuoteCard(
              key: ValueKey(state.quotes[index].id),
              quote: state.quotes[index],
              index: index,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final LoadingQuoteEntity quote;
  final int index;

  const _QuoteCard({
    required super.key,
    required this.quote,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: do NOT read the cubit in build(). During a drag, ReorderableListView
    // rebuilds this item inside an Overlay that sits outside the BlocProvider,
    // so a build-time context.read throws ProviderNotFoundException. Read it
    // only inside callbacks (which fire while the item is in the normal tree).
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (quote.source != null && quote.source!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      quote.source!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: quote.isActive,
              onChanged: (v) => context
                  .read<AdminLoadingQuotesCubit>()
                  .toggleActive(id: quote.id, isActive: v),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () => _edit(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'حذف',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<AdminLoadingQuotesCubit>();
    await context.push('/admin/loading-quotes/${quote.id}/edit', extra: quote);
    if (context.mounted) cubit.load();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AdminLoadingQuotesCubit>();
    final ok = await showConfirmDialog(
      context,
      title: 'حذف النص',
      message: 'هل تريد حذف هذا النص؟',
      confirmLabel: 'حذف',
      isDestructive: true,
      icon: Icons.delete_outline,
    );
    if (ok) cubit.deleteQuote(quote.id);
  }
}
