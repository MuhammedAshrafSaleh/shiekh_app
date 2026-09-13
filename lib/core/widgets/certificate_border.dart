// lib/core/widgets/certificate_border.dart
//
// Decorative double-border frame for certificates.
// Outer border: primary (white-label), thick.
// Inner border: gold hairline, inset by [innerInset].
// Corners: gold L-bracket lines + filled diamond at each inner corner.
// Paper background fill.
// Used by CertificateDetailPage (in-app preview) — SVG-free, all vector.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CertificateBorder extends StatelessWidget {
  const CertificateBorder({
    super.key,
    required this.child,
    this.primaryColor,
    this.goldColor,
  });

  final Widget child;

  /// Overrides for white-label. Defaults to [AppColors.primary] / [AppColors.gold].
  final Color? primaryColor;
  final Color? goldColor;

  @override
  Widget build(BuildContext context) {
    final primary = primaryColor ?? AppColors.primary;
    final gold = goldColor ?? AppColors.gold;

    return CustomPaint(
      painter: _CertificateBorderPainter(primary: primary, gold: gold),
      child: child,
    );
  }
}

class _CertificateBorderPainter extends CustomPainter {
  const _CertificateBorderPainter({required this.primary, required this.gold});

  final Color primary;
  final Color gold;

  static const double _outerWidth = 3.0;
  static const double _outerRadius = 6.0;
  static const double _innerInset = 9.0;
  static const double _innerWidth = 1.0;
  static const double _innerRadius = 3.0;
  static const double _cornerLen = 28.0;
  static const double _diamondHalf = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Paper fill
    final fillPaint = Paint()
      ..color = AppColors.paper
      ..style = PaintingStyle.fill;
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_outerRadius),
    );
    canvas.drawRRect(outerRect, fillPaint);

    // Outer border (primary)
    final outerPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outerWidth;
    canvas.drawRRect(outerRect, outerPaint);

    // Inner border (gold hairline)
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _innerInset,
        _innerInset,
        size.width - _innerInset * 2,
        size.height - _innerInset * 2,
      ),
      const Radius.circular(_innerRadius),
    );
    final innerPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = _innerWidth;
    canvas.drawRRect(innerRect, innerPaint);

    // Corner ornaments: L-brackets + diamonds
    _drawCornerOrnaments(canvas, size);
  }

  void _drawCornerOrnaments(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;
    final diamondPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.fill;

    final corners = [
      // top-right (RTL start)
      (Offset(size.width - _innerInset, _innerInset), 1.0, -1.0),
      // top-left (RTL end)
      (Offset(_innerInset, _innerInset), -1.0, -1.0),
      // bottom-right
      (Offset(size.width - _innerInset, size.height - _innerInset), 1.0, 1.0),
      // bottom-left
      (Offset(_innerInset, size.height - _innerInset), -1.0, 1.0),
    ];

    for (final (corner, sx, sy) in corners) {
      // L-bracket: horizontal arm
      canvas.drawLine(
        corner,
        Offset(corner.dx - sx * _cornerLen, corner.dy),
        bracketPaint,
      );
      // L-bracket: vertical arm
      canvas.drawLine(
        corner,
        Offset(corner.dx, corner.dy - sy * _cornerLen),
        bracketPaint,
      );

      // Filled diamond at corner point (inset so it sits on the inner border)
      final dPath = Path()
        ..moveTo(corner.dx, corner.dy - sy * _diamondHalf)
        ..lineTo(corner.dx + sx * _diamondHalf, corner.dy)
        ..lineTo(corner.dx, corner.dy + sy * _diamondHalf)
        ..lineTo(corner.dx - sx * _diamondHalf, corner.dy)
        ..close();
      canvas.drawPath(dPath, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(_CertificateBorderPainter old) =>
      old.primary != primary || old.gold != gold;
}
