// lib/core/utils/insets.dart
import 'dart:math';

import 'package:flutter/widgets.dart';

/// Bottom-inset helpers for edge-to-edge layouts (Android 15 enforces
/// edge-to-edge, so content draws behind the system nav bar / home indicator).
///
/// Usage:
/// - Scrollable list/page: add [safeBottom] to the existing bottom padding.
/// - Fixed bottom button/bar: wrap in `SafeArea(top: false, child: ...)`.
/// - Bottom sheet with a TextField: use [sheetBottomInset].
extension BottomInsets on BuildContext {
  /// System nav bar / home-indicator inset (edge-to-edge safe area).
  double get safeBottom => MediaQuery.viewPaddingOf(this).bottom;

  /// Keyboard inset (0 when the keyboard is closed).
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// For bottom sheets: `viewPadding` does NOT collapse when the keyboard
  /// opens (only `viewInsets` grows), so `keyboardInset + safeBottom` would
  /// leave a nav-bar-height gap above the keyboard. Take the max instead.
  double get sheetBottomInset => max(keyboardInset, safeBottom);
}
