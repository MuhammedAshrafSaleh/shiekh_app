// lib/features/sections/view/sections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../cubit/sections_cubit.dart';
import '../cubit/sections_state.dart';
import '../widgets/section_grid_item.dart';

class SectionsPage extends StatelessWidget {
  const SectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأقسام العلمية'),
        centerTitle: true,
      ),
      body: BlocBuilder<SectionsCubit, SectionsState>(
        builder: (context, state) {
          if (state is SectionsLoading || state is SectionsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SectionsError) {
            return ErrorState(
              message: state.message,
              onRetry: () => context.read<SectionsCubit>().loadSections(),
            );
          }

          if (state is SectionsEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              message: 'لا توجد أقسام بعد',
            );
          }

          if (state is SectionsLoaded) {
            return RefreshIndicator(
              onRefresh: () => context.read<SectionsCubit>().loadSections(),
              child: GridView.builder(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.1,
                ),
                itemCount: state.sections.length,
                itemBuilder: (context, index) =>
                    SectionGridItem(section: state.sections[index]),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
