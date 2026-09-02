// lib/features/sections/view/sections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../cubit/sections_cubit.dart';
import '../cubit/sections_state.dart';
import '../widgets/section_grid_item.dart';

class SectionsPage extends StatelessWidget {
  const SectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheikhyPageHeader(title: 'الأقسام العلمية'),
          const Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SectionsCubit, SectionsState>(
      builder: (context, state) {
        if (state is SectionsInitial || state is SectionsLoading) {
          return const _LoadingView();
        }
        if (state is SectionsError) {
          return SheikhyErrorState(
            heading: 'تعذّر تحميل الأقسام',
            message: state.message,
            onRetry: () => context.read<SectionsCubit>().loadSections(),
          );
        }
        if (state is SectionsEmpty) {
          return const SheikhyEmptyState(
            icon: Icons.category_outlined,
            heading: 'لا توجد أقسام بعد',
            subtitle: 'لم تُضَف أقسام علمية بعد.',
          );
        }
        if (state is SectionsLoaded) {
          return _LoadedView(state: state);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('جار تحميل المحتوى...', style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final SectionsLoaded state;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => context.read<SectionsCubit>().loadSections(),
      child: GridView.builder(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.s3,
          mainAxisSpacing: AppSpacing.s3,
          childAspectRatio: 1.1,
        ),
        itemCount: state.sections.length,
        itemBuilder: (context, index) =>
            SectionGridItem(section: state.sections[index]),
      ),
    );
  }
}
