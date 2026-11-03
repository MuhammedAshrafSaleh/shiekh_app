// lib/core/widgets/girih_background.dart
//
// Geometric lattice backgrounds (girih + arabesque), tiled over a unit grid.
// Vector CustomPainters — PNG-free and programmatically colored so they recolor
// with any primary/gold. Geometry from design/Sheikhi Design System.dc.html.
//
// RULE (DESIGN_SYSTEM.md §1): patterns are for headers/card-heads/empty
// backgrounds ONLY — never under running text. Keep opacity low.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Faint girih lattice, meant for empty backgrounds on paper (unit 56).
class GirihBackground extends StatelessWidget {
  const GirihBackground({
    super.key,
    this.color,
    this.opacity = 0.10, // pattern.girih.opacityOnPaper
    this.unit = 56,
  });

  final Color? color;
  final double opacity;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GirihPainter(
        color: color ?? AppColors.primary,
        opacity: opacity,
        unit: unit,
      ),
      size: Size.infinite,
    );
  }
}

/// girih unit motif (skGirihPaper) — nested diamonds + radial spokes.
class GirihPainter extends CustomPainter {
  GirihPainter({required this.color, required this.opacity, this.unit = 56});

  final Color color;
  final double opacity;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: opacity);

    for (double oy = 0; oy < size.height; oy += unit) {
      for (double ox = 0; ox < size.width; ox += unit) {
        canvas.save();
        canvas.translate(ox, oy);
        canvas.drawPath(_tile(unit), paint);
        canvas.restore();
      }
    }
  }

  static Path _tile(double u) {
    final h = u / 2;
    final q = u * 0.196; // ~11/56
    return Path()
      // outer diamond
      ..moveTo(h, 0)
      ..lineTo(u, h)
      ..lineTo(h, u)
      ..lineTo(0, h)
      ..close()
      // inner diamond
      ..moveTo(h, q)
      ..lineTo(u - q, h)
      ..lineTo(h, u - q)
      ..lineTo(q, h)
      ..close()
      // corner spokes
      ..moveTo(0, 0)
      ..lineTo(q, h)
      ..lineTo(0, u)
      ..moveTo(u, 0)
      ..lineTo(u - q, h)
      ..lineTo(u, u)
      ..moveTo(0, 0)
      ..lineTo(h, q)
      ..lineTo(u, 0)
      ..moveTo(0, u)
      ..lineTo(h, u - q)
      ..lineTo(u, u);
  }

  @override
  bool shouldRepaint(GirihPainter old) =>
      old.color != color || old.opacity != opacity || old.unit != unit;
}

/// arabesque unit motif (skArabesque) — diamond + diagonal spokes (unit 44).
/// Used behind course-card heads over the primary color.
class ArabesquePainter extends CustomPainter {
  ArabesquePainter({
    required this.color,
    required this.opacity,
    this.unit = 44,
  });

  final Color color;
  final double opacity;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: opacity);

    for (double oy = 0; oy < size.height; oy += unit) {
      for (double ox = 0; ox < size.width; ox += unit) {
        canvas.save();
        canvas.translate(ox, oy);
        canvas.drawPath(_tile(unit), paint);
        canvas.restore();
      }
    }
  }

  static Path _tile(double u) {
    final h = u / 2;
    return Path()
      ..moveTo(h, 0)
      ..lineTo(u, h)
      ..lineTo(h, u)
      ..lineTo(0, h)
      ..close()
      ..moveTo(0, 0)
      ..lineTo(h, h)
      ..lineTo(u, 0)
      ..moveTo(0, u)
      ..lineTo(h, h)
      ..lineTo(u, u);
  }

  @override
  bool shouldRepaint(ArabesquePainter old) =>
      old.color != color || old.opacity != opacity || old.unit != unit;
}
