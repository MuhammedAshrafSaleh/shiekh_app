// lib/core/widgets/sheikhy_card.dart
//
// Base heritage card: white surface, hairline border, lg radius, soft shadow.
// Spec: DESIGN_SYSTEM.md §5.
import 'package:flutter/material.dart';

import '../theme/app_decorations.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class SheikhyCard extends StatelessWidget {
  const SheikhyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s5),
    this.onTap,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final decoration = raised ? AppDecorations.raised : AppDecorations.card;
    final inner = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(decoration: decoration, child: inner);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: AppRadii.rLg,
          onTap: onTap,
          child: inner,
        ),
      ),
    );
  }
}
