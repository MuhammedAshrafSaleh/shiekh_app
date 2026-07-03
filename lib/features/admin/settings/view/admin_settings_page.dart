// lib/features/admin/settings/view/admin_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_cubit.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        children: [
          _SectionHeader('إدارة المحتوى'),
          _SettingsTile(
            icon: Icons.category_outlined,
            title: 'الأقسام العلمية',
            subtitle: 'إضافة وتعديل وحذف الأقسام',
            onTap: () => context.push('/admin/sections'),
          ),
          _SettingsTile(
            icon: Icons.view_carousel_outlined,
            title: 'بانرات الرئيسية',
            subtitle: 'إدارة البانرات والإعلانات',
            onTap: () => context.push('/admin/banners'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader('تفضيلات التطبيق'),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeState) {
              final isDark = themeState == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.gold,
                ),
                title: const Text('الوضع الليلي'),
                value: isDark,
                onChanged: (_) =>
                    context.read<ThemeCubit>().toggle(),
                activeThumbColor: AppColors.gold,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppSpacing.xs,
        top: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
