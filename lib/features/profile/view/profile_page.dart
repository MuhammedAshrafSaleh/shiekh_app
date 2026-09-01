// lib/features/profile/view/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../core/theme/theme_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../data/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return switch (state) {
            ProfileInitial() || ProfileLoading() =>
              const Center(child: CircularProgressIndicator()),
            ProfileError(:final message) => ErrorState(
                message: message,
                onRetry: () => context.read<ProfileCubit>().loadProfile(),
              ),
            ProfileLoaded() => RefreshIndicator(
                onRefresh: () => context.read<ProfileCubit>().loadProfile(),
                child: _ProfileView(stats: state.stats),
              ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final ProfileStats stats;
  const _ProfileView({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Avatar + name + email
        Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            InitialsAvatar(name: stats.fullName, radius: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              stats.fullName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              stats.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),

        // 3 stats row — colors mirror إنجازاتي: primary / gold / secondary
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          const gold = Color(0xFFD4A017);
          return Row(
            children: [
              _StatChip(
                label: 'كتاب مسجّل',
                value: '${stats.enrolledBooks}',
                icon: Icons.menu_book_outlined,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(
                label: 'درس مكتمل',
                value: '${stats.completedLessons}',
                icon: Icons.check_circle_outline,
                color: gold,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(
                label: 'شهادة',
                value: '${stats.certificates}',
                icon: Icons.emoji_events_outlined,
                color: cs.secondary,
              ),
            ],
          );
        }),
        const SizedBox(height: AppSpacing.lg),

        // Menu list
        Card(
          child: Column(
            children: [
              _MenuItem(
                icon: Icons.emoji_events_outlined,
                label: 'شهاداتي',
                onTap: () => context.push('/achievements'),
              ),
              const Divider(height: 1, indent: AppSpacing.xl),
              _MenuItem(
                icon: Icons.question_answer_outlined,
                label: 'أسئلتي',
                onTap: () => context.push('/my-questions'),
              ),
              const Divider(height: 1, indent: AppSpacing.xl),
              _MenuItem(
                icon: Icons.lock_outline,
                label: 'تغيير كلمة المرور',
                onTap: () => context.push('/profile/edit-password'),
              ),
              const Divider(height: 1, indent: AppSpacing.xl),
              _DarkModeMenuItem(),
              const Divider(height: 1, indent: AppSpacing.xl),
              _MenuItem(
                icon: Icons.info_outline,
                label: 'عن التطبيق',
                onTap: () => _showAboutDialog(context),
              ),
              const Divider(height: 1, indent: AppSpacing.xl),
              _MenuItem(
                icon: Icons.logout,
                label: 'تسجيل الخروج',
                color: colorScheme.error,
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.sheikhName,
      applicationVersion: '1.0.0',
      children: const [
        Text('تطبيق تعليمي إسلامي لمتابعة دروس الشيخ وأخذ الاختبارات والحصول على الشهادات.'),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthCubit>().signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: effective),
      title: Text(label, style: TextStyle(color: effective)),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: effective.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}

class _DarkModeMenuItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return ListTile(
          leading: Icon(
            mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
          ),
          title: const Text('الوضع الليلي'),
          trailing: Switch(
            value: mode == ThemeMode.dark,
            onChanged: (_) => context.read<ThemeCubit>().toggle(),
          ),
        );
      },
    );
  }
}
