// lib/core/widgets/ornament_divider.dart
//
// Decorative section divider: two fading rules flanking a small gold motif
// (diamonds + triangles + circles). Geometry from
// design/Sheikhi Design System.dc.html (viewBox 0 0 86 22).
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.color, this.motifWidth = 86});

  final Color? color;
  final double motifWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _FadeRule(fadeToStart: false)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          child: SizedBox(
            width: motifWidth,
            height: motifWidth * 22 / 86,
            child: CustomPaint(
              painter: _OrnamentMotifPainter(color: color ?? AppColors.gold),
            ),
          ),
        ),
        const Expanded(child: _FadeRule(fadeToStart: true)),
      ],
    );
  }
}

class _FadeRule extends StatelessWidget {
  const _FadeRule({required this.fadeToStart});

  /// Whether the transparent end is on the start (leading) side.
  final bool fadeToStart;

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.transparent, AppColors.border, AppColors.border];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fadeToStart
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          end: fadeToStart
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          colors: colors,
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }
}

class _OrnamentMotifPainter extends CustomPainter {
  _OrnamentMotifPainter({required this.color});

  final Color color;
  static const double _vbW = 86;
  static const double _vbH = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.55);

    // center diamond (outline)
    canvas.drawPath(
      Path()
        ..moveTo(p(43, 1).dx, p(43, 1).dy)
        ..lineTo(p(53, 11).dx, p(53, 11).dy)
        ..lineTo(p(43, 21).dx, p(43, 21).dy)
        ..lineTo(p(33, 11).dx, p(33, 11).dy)
        ..close(),
      stroke,
    );
    // inner diamond (filled)
    canvas.drawPath(
      Path()
        ..moveTo(p(43, 6).dx, p(43, 6).dy)
        ..lineTo(p(48, 11).dx, p(48, 11).dy)
        ..lineTo(p(43, 16).dx, p(43, 16).dy)
        ..lineTo(p(38, 11).dx, p(38, 11).dy)
        ..close(),
      fill,
    );
    // flanking triangles
    canvas.drawPath(
      Path()
        ..moveTo(p(23, 11).dx, p(23, 11).dy)
        ..lineTo(p(30, 4).dx, p(30, 4).dy)
        ..lineTo(p(30, 18).dx, p(30, 18).dy)
        ..close()
        ..moveTo(p(63, 11).dx, p(63, 11).dy)
        ..lineTo(p(56, 4).dx, p(56, 4).dy)
        ..lineTo(p(56, 18).dx, p(56, 18).dy)
        ..close(),
      stroke,
    );
    // end circles
    canvas.drawCircle(p(12, 11), 3 * sx, stroke);
    canvas.drawCircle(p(74, 11), 3 * sx, stroke);
  }

  @override
  bool shouldRepaint(_OrnamentMotifPainter old) => old.color != color;
}
