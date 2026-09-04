// lib/features/onboarding/view/onboarding_slide_widget.dart
//
// A single onboarding slide rendered on the primary (green) field: a centered
// MihrabArch gold ornament ~40% from top, then the slide's text block.
//   - hadith: mainText in Aref Ruqaa (display), gold; optional subText in body.
//   - normal: mainText in Reem Kufi (h2), paper; subText in body, paper.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../models/onboarding_slide_entity.dart';

class OnboardingSlideWidget extends StatelessWidget {
  const OnboardingSlideWidget({super.key, required this.slide});

  final OnboardingSlideEntity slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.pageGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Push the ornament to ~40% from the top of the slide area.
          const Spacer(flex: 4),
          const MihrabArch(width: 96, height: 108),
          const SizedBox(height: AppSpacing.s7),
          _mainText(),
          if (slide.subText != null && slide.subText!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            _subText(),
          ],
          const Spacer(flex: 6),
        ],
      ),
    );
  }

  Widget _mainText() {
    // All slide types share the same title treatment: Aref Ruqaa 700, white.
    final style = AppTextStyles.displaySm.copyWith(color: AppColors.surface);
    return Text(slide.mainText, textAlign: TextAlign.center, style: style);
  }

  Widget _subText() {
    final color = slide.isHadith ? AppColors.goldLight : AppColors.inkInvert;
    return Text(
      slide.subText!,
      textAlign: TextAlign.center,
      style: AppTextStyles.body.copyWith(color: color.withValues(alpha: 0.9)),
    );
  }
}
