// lib/features/home/view/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../features/auth/cubit/auth_state.dart';
import '../../../models/banner_entity.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/banner_carousel_section.dart';
import '../widgets/featured_book_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Reads the signed-in student's first name from auth metadata.
  String _studentName(BuildContext context) {
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      final full = state.user.userMetadata?['full_name'] as String?;
      if (full != null && full.trim().isNotEmpty) {
        return full.trim().split(RegExp(r'\s+')).first;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final name = _studentName(context);
    final greeting = name.isEmpty ? 'السلام عليكم' : 'السلام عليكم، $name';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            InitialsAvatar(name: name.isEmpty ? '؟' : name, radius: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                greeting,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'الإشعارات',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading || state is HomeInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeError) {
            return ErrorState(
              message: state.message,
              onRetry: () => context.read<HomeCubit>().loadHome(),
            );
          }

          if (state is HomeEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'لا يوجد محتوى بعد',
            );
          }

          if (state is HomeLoaded) {
            return RefreshIndicator(
              onRefresh: () => context.read<HomeCubit>().loadHome(),
              child: CustomScrollView(
                slivers: [
                  if (state.data.banners.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.md,
                          bottom: AppSpacing.sm,
                        ),
                        child: BannerCarouselSection(
                          banners: state.data.banners,
                          onTap: (banner) => _handleBannerTap(context, banner),
                        ),
                      ),
                    ),
                  if (state.data.featuredBooks.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                          end: AppSpacing.sm,
                          top: AppSpacing.md,
                          bottom: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'الكتب والدورات',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/path'),
                              child: const Text('عرض الكل'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      sliver: SliverList.builder(
                        itemCount: state.data.featuredBooks.length,
                        itemBuilder: (context, index) {
                          final item = state.data.featuredBooks[index];
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: FeaturedBookCard(
                              item: item,
                              onTap: () =>
                                  context.go('/books/${item.book.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _handleBannerTap(
    BuildContext context,
    BannerEntity banner,
  ) async {
    if (banner.linkedBookId != null) {
      context.go('/books/${banner.linkedBookId}');
    } else if (banner.externalLink != null) {
      final uri = Uri.tryParse(banner.externalLink!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
