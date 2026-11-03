// lib/core/widgets/mihrab_arch.dart
//
// Mihrab (pointed-arch) ornament — two nested arch outlines. Vector, PNG-free,
// recolors programmatically so it stays white-label-safe.
// Geometry traced from design/Sheikhi Design System.dc.html (course-card head,
// viewBox 0 0 112 126).
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MihrabArch extends StatelessWidget {
  const MihrabArch({
    super.key,
    this.width = 112,
    this.height = 126,
    this.color,
    this.accentColor,
    this.strokeWidth = 1.4,
  });

  final double width;
  final double height;

  /// Outer arch stroke. Defaults to [AppColors.goldLight].
  final Color? color;

  /// Inner arch stroke. Defaults to [AppColors.gold].
  final Color? accentColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MihrabArchPainter(
          outer: color ?? AppColors.goldLight,
          inner: accentColor ?? AppColors.gold,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _MihrabArchPainter extends CustomPainter {
  _MihrabArchPainter({
    required this.outer,
    required this.inner,
    required this.strokeWidth,
  });

  final Color outer;
  final Color inner;
  final double strokeWidth;

  // Source viewBox dimensions.
  static const double _vbW = 112;
  static const double _vbH = 126;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    // Outer arch: M56 4 C86 26 108 42 108 66 V124 H4 V66 C4 42 26 26 56 4 Z
    final outerPath = Path()
      ..moveTo(p(56, 4).dx, p(56, 4).dy)
      ..cubicTo(
        p(86, 26).dx,
        p(86, 26).dy,
        p(108, 42).dx,
        p(108, 42).dy,
        p(108, 66).dx,
        p(108, 66).dy,
      )
      ..lineTo(p(108, 124).dx, p(108, 124).dy)
      ..lineTo(p(4, 124).dx, p(4, 124).dy)
      ..lineTo(p(4, 66).dx, p(4, 66).dy)
      ..cubicTo(
        p(4, 42).dx,
        p(4, 42).dy,
        p(26, 26).dx,
        p(26, 26).dy,
        p(56, 4).dx,
        p(56, 4).dy,
      )
      ..close();

    // Inner arch: M56 26 C76 42 92 52 92 70 V124 H20 V70 C20 52 36 42 56 26 Z
    final innerPath = Path()
      ..moveTo(p(56, 26).dx, p(56, 26).dy)
      ..cubicTo(
        p(76, 42).dx,
        p(76, 42).dy,
        p(92, 52).dx,
        p(92, 52).dy,
        p(92, 70).dx,
        p(92, 70).dy,
      )
      ..lineTo(p(92, 124).dx, p(92, 124).dy)
      ..lineTo(p(20, 124).dx, p(20, 124).dy)
      ..lineTo(p(20, 70).dx, p(20, 70).dy)
      ..cubicTo(
        p(20, 52).dx,
        p(20, 52).dy,
        p(36, 42).dx,
        p(36, 42).dy,
        p(56, 26).dx,
        p(56, 26).dy,
      )
      ..close();

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = outer.withValues(alpha: 0.8);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..color = inner.withValues(alpha: 0.7);

    canvas.drawPath(outerPath, outerPaint);
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(_MihrabArchPainter old) =>
      old.outer != outer ||
      old.inner != inner ||
      old.strokeWidth != strokeWidth;
}
