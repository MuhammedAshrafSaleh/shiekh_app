// lib/features/profile/view/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
// import '../../../core/theme/theme_cubit.dart'; // re-enable with _ThemeModeRow
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
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
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SheikhyPageHeader(title: 'حسابي'),
          Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state is ProfileInitial || state is ProfileLoading) {
          return const _LoadingView();
        }
        if (state is ProfileError) {
          return SheikhyErrorState(
            heading: 'تعذّر تحميل الملف الشخصي',
            message: state.message,
            onRetry: () => context.read<ProfileCubit>().loadProfile(),
          );
        }
        if (state is ProfileLoaded) {
          return _LoadedView(stats: state.stats);
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

// ── Loaded view ───────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s5,
        AppSpacing.pageGutter,
        AppSpacing.s9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AvatarSection(stats: stats),
          const SizedBox(height: AppSpacing.s5),
          // A guest has no meaningful stats (all zeros) — replace the row with a
          // prominent convert CTA, which is the whole point of this screen.
          if (isGuest) ...[
            const _GuestConvertCta(),
            const SizedBox(height: AppSpacing.s5),
          ] else ...[
            _StatsRow(stats: stats),
            const SizedBox(height: AppSpacing.s5),
          ],
          _ActionsList(stats: stats, isGuest: isGuest),
        ],
      ),
    );
  }
}

// ── Guest convert CTA ─────────────────────────────────────────────────────────

class _GuestConvertCta extends StatelessWidget {
  const _GuestConvertCta();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheikhyButton.primary(
          fullWidth: true,
          label: 'أنشئ حساباً',
          icon: const Icon(Icons.person_add_alt_1_outlined),
          onPressed: () => context.push(
            Uri(
              path: '/signup',
              queryParameters: const {'returnTo': '/profile'},
            ).toString(),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'أنشئ حساباً لحفظ تقدّمك والحصول على الشهادات',
          style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.stats});

  final ProfileStats stats;

  String get _initials {
    final words = stats.fullName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '؟';
    if (words.length == 1) return words.first.characters.first;
    return words.first.characters.first + words.last.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    // A guest carries an internal <uuid>@guest.sheikhy.local placeholder email
    // that must never be user-facing: show "زائر" and hide the email entirely.
    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;
    final displayName = isGuest ? 'زائر' : stats.fullName;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.goldSoft,
          child: Text(
            isGuest ? 'ز' : _initials,
            style: GoogleFonts.arefRuqaa(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.goldDeep,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          displayName,
          style: GoogleFonts.arefRuqaa(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: AppColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        if (!isGuest) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            stats.email,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final ProfileStats stats;

  String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // RTL: كتاب مسجّل (start/right)
            Expanded(
              child: _StatCell(
                icon: Icons.menu_book_outlined,
                value: _ar(stats.enrolledBooks),
                label: 'كتاب مسجّل',
                color: AppColors.inkMuted,
              ),
            ),
            const _VerticalDivider(),
            // Center: درس مكتمل (highlighted gold)
            Expanded(
              child: _StatCell(
                icon: Icons.check_circle_outline,
                value: _ar(stats.completedLessons),
                label: 'درس مكتمل',
                color: AppColors.goldDeep,
                highlighted: true,
              ),
            ),
            const _VerticalDivider(),
            // RTL: شهادة (end/left)
            Expanded(
              child: _StatCell(
                icon: Icons.workspace_premium_outlined,
                value: _ar(stats.certificates),
                label: 'شهادة',
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.highlighted = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final valueColor = highlighted ? AppColors.goldDeep : AppColors.ink;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.s4,
        horizontal: AppSpacing.s2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            value,
            style: GoogleFonts.reemKufi(
              fontSize: highlighted ? 26 : 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBorders.hairline,
      color: AppColors.border,
    );
  }
}

// ── Actions list ──────────────────────────────────────────────────────────────

class _ActionsList extends StatelessWidget {
  const _ActionsList({required this.stats, required this.isGuest});

  final ProfileStats stats;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Aspirational tiles: shown to guests but gated. guard() navigates a
          // registered user and shows the account sheet for a guest (returning
          // to the tile's own destination after they convert).
          _ActionRow(
            icon: Icons.workspace_premium_outlined,
            label: 'شهاداتي',
            onTap: () => AccountGate.guard(
              context,
              returnTo: '/achievements',
              onAllowed: () => context.go('/achievements'),
            ),
          ),
          const _RowDivider(),
          _ActionRow(
            icon: Icons.chat_bubble_outline,
            label: 'أسئلتي',
            onTap: () => AccountGate.guard(
              context,
              returnTo: '/my-questions',
              onAllowed: () => context.push('/my-questions'),
            ),
          ),
          const _RowDivider(),
          // A guest has no password to change — hide it entirely.
          if (!isGuest) ...[
            _ActionRow(
              icon: Icons.lock_outline,
              label: 'تغيير كلمة المرور',
              onTap: () => context.push('/profile/edit-password'),
            ),
            const _RowDivider(),
          ],
          // _ThemeModeRow(), // hidden — dark mode toggle not active in v1
          const _RowDivider(),
          _ActionRow(
            icon: Icons.info_outline,
            label: 'عن التطبيق',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('عن التطبيق — قريباً'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            ),
          ),
          const _RowDivider(),
          _ActionRow(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            color: AppColors.danger,
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.reemKufi(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل تريد تسجيل الخروج من حسابك؟',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'إلغاء',
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.inkInvert,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s5,
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthCubit>().signOut();
            },
            child: Text('خروج', style: AppTextStyles.buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s4,
          ),
          child: Row(
            children: [
              // RTL: icon is first child = rightmost (start)
              Icon(icon, color: c, size: 20),
              const SizedBox(width: AppSpacing.s3),
              Text(
                label,
                style: AppTextStyles.small.copyWith(
                  color: c,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Chevron is last child = leftmost (end) in RTL
              Icon(Icons.chevron_left, color: AppColors.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// class _ThemeModeRow extends StatelessWidget {
//   const _ThemeModeRow();
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsetsDirectional.symmetric(
//         horizontal: AppSpacing.s4,
//         vertical: AppSpacing.s3,
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.dark_mode_outlined, color: AppColors.ink, size: 20),
//           const SizedBox(width: AppSpacing.s3),
//           Text('الوضع الليلي', style: AppTextStyles.small),
//           const Spacer(),
//           BlocBuilder<ThemeCubit, ThemeMode>(
//             builder: (context, mode) => Switch(
//               value: mode == ThemeMode.dark,
//               onChanged: (_) => context.read<ThemeCubit>().toggle(),
//               activeThumbColor: AppColors.primary,
//               activeTrackColor: AppColors.primaryTint,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: AppBorders.hairline,
      color: AppColors.border,
      indent: AppSpacing.s4,
      endIndent: AppSpacing.s4,
    );
  }
}
