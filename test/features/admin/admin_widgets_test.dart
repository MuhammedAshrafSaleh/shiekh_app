// test/features/admin/admin_widgets_test.dart
//
// Widget tests for Phase 6 admin UI — covers:
//   • StatusBadge renders correct Arabic text for all 6 status variants
//   • Dual status axes shown for books (publish_status + review_status)
//   • CC-24: featured-cap warning SnackBar fires when toggling above 5
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/core/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  home: Scaffold(body: Center(child: child)),
);

// ---------------------------------------------------------------------------
// StatusBadge — dual-axis tests
// ---------------------------------------------------------------------------
void main() {
  group('StatusBadge', () {
    testWidgets('shows "منشور" for BadgeStatus.published', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.published)),
      );
      expect(find.text('منشور'), findsOneWidget);
    });

    testWidgets('shows "مسودة" for BadgeStatus.draft', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.draft)),
      );
      expect(find.text('مسودة'), findsOneWidget);
    });

    testWidgets('shows "مكتمل" for BadgeStatus.completed', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.completed)),
      );
      expect(find.text('مكتمل'), findsOneWidget);
    });

    testWidgets('shows "قيد المراجعة" for BadgeStatus.inReview', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.inReview)),
      );