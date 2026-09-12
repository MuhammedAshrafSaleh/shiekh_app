// lib/features/auth/view/splash_page.dart
//
// Heritage redesign (Auth Phase 1, screen 1a). Dark-green (primary) canvas with
// a faint girih lattice, the sheikh photo in a gold ring, ceremonial name
// (Aref Ruqaa), subtitle, animated loading dots, and a bottom tagline.
// Visual-only migration — no auth logic here. Spec: design/screens/auth/1a.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/audio/app_sound.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/config/brand.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/girih_background.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Per-deployment white-label photo. Falls back to initials if absent.
  static const String _sheikhPhotoAsset = 'assets/images/sheikh.png';

  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SoundService>().play(AppSound.splash);
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const Positioned.fill(
            child: GirihBackground(color: AppColors.goldLight, opacity: 0.14),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.pageGutter,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _Avatar(
                      asset: _sheikhPhotoAsset,
                      fallbackInitials: _initials(Brand.sheikhName),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Brand.sheikhName,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display.copyWith(
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'دروسٌ ومتونٌ في العلم الشرعي',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkInvert.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(flex: 3),
                    _AnimatedDots(controller: _dotController),
                    const SizedBox(height: AppSpacing.s5),
                    Text(
                      'طلبُ العلم فريضة',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkInvert.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : 'ش';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.asset, required this.fallbackInitials});

  final String asset;
  final String fallbackInitials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 3),
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.primaryDeep,
      alignment: Alignment.center,
      child: Text(
        fallbackInitials,
        style: AppTextStyles.h1.copyWith(color: AppColors.goldLight),
      ),
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  const _AnimatedDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.3;
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s1,
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = (controller.value - delay).clamp(0.0, 1.0);
              return Opacity(
                opacity: 0.3 + 0.7 * t,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == 1 ? AppColors.gold : AppColors.goldLight,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
