// lib/features/home/view/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_home_header.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../features/auth/cubit/auth_state.dart';
import '../../../features/notifications/cubit_notifs/notifications_cubit.dart';
import '../../../features/notifications/cubit_notifs/notifications_state.dart';
import '../../../models/banner_entity.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/banner_carousel_section.dart';
import '../widgets/featured_book_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<NotificationsCubit, NotificationsState, int>(
            selector: (state) =>
                state is NotificationsLoaded ? state.unreadCount : 0,
            builder: (context, unreadCount) => SheikhyHomeHeader(
              name: name,
              unreadCount: unreadCount,
              onNotificationTap: () => context.push('/notifications'),
            ),
          ),
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
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is HomeInitial || state is HomeLoading) {
          return const _LoadingView();
        }
        if (state is HomeError) {
          return SheikhyErrorState(
            heading: 'تعذّر تحميل المحتوى',
            message: state.message,
            onRetry: () => context.read<HomeCubit>().loadHome(),
          );
        }
        if (state is HomeEmpty) {
          return const SheikhyEmptyState(
            icon: Icons.menu_book_outlined,
            heading: 'لا يوجد محتوى بعد',
            subtitle: 'سيظهر هنا ما يُضاف إليك من كتب ودورات.',
          );
        }
        if (state is HomeLoaded) {
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

  final HomeLoaded state;

  Future<void> _handleBannerTap(
    BuildContext context,
    BannerEntity banner,
  ) async {
    if (banner.linkedBookId != null) {
      context.push('/books/${banner.linkedBookId}');
    } else if (banner.externalLink != null) {
      final uri = Uri.tryParse(banner.externalLink!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => Future.wait([
        context.read<HomeCubit>().loadHome(),
        context.read<NotificationsCubit>().loadNotifications(),
      ]),
      child: CustomScrollView(
        slivers: [
          if (state.data.banners.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: AppSpacing.s4,
                  bottom: AppSpacing.s2,
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
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s4,
                  AppSpacing.pageGutter,
                  AppSpacing.s3,
                ),
                child: Row(
                  children: [
                    Text('الكتب والدورات', style: AppTextStyles.h3),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/path'),
                      child: Text(
                        'عرض الكل',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.goldDeep,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.goldDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.pageGutter,
              ),
              sliver: SliverList.builder(
                itemCount: state.data.featuredBooks.length,
                itemBuilder: (context, index) {
                  final item = state.data.featuredBooks[index];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.s3,
                    ),
                    child: FeaturedBookCard(
                      item: item,
                      onTap: () => context.push('/books/${item.book.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s7)),
        ],
      ),
    );
  }
}
