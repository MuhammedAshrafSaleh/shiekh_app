// lib/core/theme/app_radii.dart
//
// Corner radii. Source of truth: design/design_tokens.json (radius.*).
// The `arch` token (mihrab path) is a shape, not a radius — see MihrabArch.
import 'package:flutter/widgets.dart';

abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  // Convenience BorderRadius values.
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}
