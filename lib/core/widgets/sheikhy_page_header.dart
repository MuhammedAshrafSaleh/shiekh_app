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
    this.height = 56,
  });

  final String title;
  final bool showBack;

  /// Optional widget placed at end (left in RTL) — e.g. a "mark all read"
  /// text button. Title padding widens automatically to avoid overlap.
  final Widget? action;

  /// Content height below the status-bar SafeArea. Defaults to 56 (compact).
  /// Use 72 for screens that deserve a slightly more prominent header.
  final double height;

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
              height: height,
              child: Row(
                children: [
                  // Back arrow at START (= right edge in RTL)
                  if (showBack)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.inkInvert,
                        size: 20,
                      ),
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: AppSpacing.s4),
                  // Title — start-aligned (right in RTL), expanded
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.reemKufi(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.inkInvert,
                      ),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Secondary action at END (= left edge in RTL)
                  if (action != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.s2,
                      ),
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
