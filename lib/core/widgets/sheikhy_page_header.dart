// lib/core/widgets/sheikhy_page_header.dart
//
// Compact heritage page header: primary green + girih pattern + SafeArea +
// centered Reem Kufi title. Used by all non-home shell destinations and
// sub-pages. showBack=true places a back arrow at the end edge (RTL: right).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'girih_background.dart';

class SheikhyPageHeader extends StatelessWidget {
  const SheikhyPageHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.action,
  });

  final String title;
  final bool showBack;

  /// Optional widget placed at start (right in RTL) — e.g. a "mark all read"
  /// text button. Title padding widens automatically to avoid overlap.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: GirihBackground(
              color: AppColors.goldLight,
              opacity: 0.14,
            ),
          ),
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: (showBack || action != null)
                          ? AppSpacing.s7 + AppSpacing.s4
                          : AppSpacing.s7,
                    ),
                    child: Text(
                      title,
                      style: GoogleFonts.reemKufi(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.inkInvert,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showBack)
                    PositionedDirectional(
                      end: AppSpacing.s2,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.inkInvert,
                          size: 20,
                        ),
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  if (action != null)
                    PositionedDirectional(
                      start: AppSpacing.s2,
                      child: action!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
