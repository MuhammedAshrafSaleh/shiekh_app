// lib/features/onboarding/view/onboarding_page.dart
//
// Dynamic, admin-managed onboarding carousel shown before login. Slides come
// from the `onboarding_slides` table via OnboardingCubit. Heritage look: a
// primary (green) field with a faint girih lattice, MihrabArch ornament per
// slide, StepDots, and a gold primary CTA ("التالي" / "ابدأ").
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/cubit/auth_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/girih_background.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/step_dots.dart';
import '../../../models/onboarding_slide_entity.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';
import 'onboarding_slide_widget.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const Positioned.fill(
            child: GirihBackground(color: AppColors.paper, opacity: 0.14),
          ),
          SafeArea(
            child: BlocBuilder<OnboardingCubit, OnboardingState>(
              builder: (context, state) {
                if (state is OnboardingError) {
                  return _ErrorView(message: state.message);
                }
                if (state is OnboardingLoaded) {
                  if (state.slides.isEmpty) {
                    // Defensive: an empty/misconfigured table must never trap the
                    // user on a blank onboarding screen.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) context.go('/login');
                    });
                    return const _LoadingView();
                  }
                  return _OnboardingCarousel(slides: state.slides);
                }
                return const _LoadingView();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.goldLight),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.inkInvert),
          ),
          const SizedBox(height: AppSpacing.s5),
          SheikhyButton.secondary(
            label: 'إعادة المحاولة',
            onPressed: () => context.read<OnboardingCubit>().loadSlides(),
          ),
          const SizedBox(height: AppSpacing.s3),
          SheikhyButton.text(
            label: 'تخطي',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCarousel extends StatefulWidget {
  const _OnboardingCarousel({required this.slides});

  final List<OnboardingSlideEntity> slides;

  @override
  State<_OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<_OnboardingCarousel> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _index == widget.slides.length - 1;

  void _goToLogin() => context.go('/login');

  void _onPrimaryTap() {
    if (_isLast) {
      _goToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "تخطي" top-end.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.s4,
              top: AppSpacing.s2,
            ),
            child: TextButton(
              onPressed: _goToLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkInvert,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                minimumSize: const Size(64, 48),
              ),
              child: Text(
                'تخطي',
                style: AppTextStyles.buttonLabel.copyWith(
                  color: AppColors.inkInvert,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                OnboardingSlideWidget(slide: widget.slides[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.pageGutter,
            AppSpacing.s2,
            AppSpacing.pageGutter,
            AppSpacing.s6,
          ),
          child: Column(
            children: [
              // Constrain the dots so the segments read as dots, not full-width bars.
              SizedBox(
                width: (widget.slides.length * 28).toDouble(),
                child: StepDots(
                  total: widget.slides.length,
                  current: _index + 1,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              SheikhyButton.gold(
                label: _isLast ? 'ابدأ' : 'التالي',
                onPressed: _onPrimaryTap,
                fullWidth: true,
              ),
              // Guest entry point — final slide only. Starts an anonymous
              // session; the auth-state change routes the guest to /home.
              if (_isLast) ...[
                const SizedBox(height: AppSpacing.s3),
                InkWell(
                  onTap: () => context.read<AuthCubit>().continueAsGuest(),
                  borderRadius: AppRadii.rMd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.s3,
                      vertical: AppSpacing.s2,
                    ),
                    child: Text(
                      'متابعة كزائر',
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: AppColors.surface,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.goldLight,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
