// lib/features/practice/widgets/practice_navigator_grid.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Question map for the practice exam: numbered circles, tinted when answered,
/// filled when current. Mirrors the final-exam navigator but keyed by the
/// ordered question IDs.
class PracticeNavigatorGrid extends StatelessWidget {
  final List<String> questionIds;
  final Map<String, String> answers;
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  const PracticeNavigatorGrid({
    super.key,
    required this.questionIds,
    required this.answers,
    required this.currentIndex,
    required this.onNavigate,
  });

  static String _ar(int n) {
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.border, width: AppBorders.hairline),
      ),
      child: Column(
        children: [
          Text(
            'خارطة الأسئلة',
            style: AppTextStyles.small.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 8;
              const spacing = AppSpacing.s2;
              final cellSize =
                  (constraints.maxWidth - (cols - 1) * spacing) / cols;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(questionIds.length, (index) {
                  final isCurrent = index == currentIndex;
                  final isAnswered = answers.containsKey(questionIds[index]);

                  final Color cellBg;
                  final Color cellBorder;
                  final Color cellText;
                  if (isCurrent) {
                    cellBg = AppColors.primary;
                    cellBorder = Colors.transparent;
                    cellText = AppColors.paper;
                  } else if (isAnswered) {
                    cellBg = AppColors.primaryTint;
                    cellBorder = Colors.transparent;
                    cellText = AppColors.primary;
                  } else {
                    cellBg = AppColors.surface;
                    cellBorder = AppColors.border;
                    cellText = AppColors.inkMuted;
                  }

                  return GestureDetector(
                    onTap: () => onNavigate(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cellBg,
                        border: Border.all(
                          color: cellBorder,
                          width: AppBorders.hairline,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _ar(index + 1),
                        style: AppTextStyles.caption.copyWith(
                          color: cellText,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
