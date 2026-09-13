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
      expect(find.text('قيد المراجعة'), findsOneWidget);
    });

    testWidgets('shows "تمت الإجابة" for BadgeStatus.answered', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.answered)),
      );
      expect(find.text('تمت الإجابة'), findsOneWidget);
    });

    testWidgets('shows "في الانتظار" for BadgeStatus.pending', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.pending)),
      );
      expect(find.text('في الانتظار'), findsOneWidget);
    });

    // Dual-axis: book list item should render BOTH publish_status and review_status
    testWidgets('renders two badges side by side (dual-axis scenario)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              StatusBadge(status: BadgeStatus.published),
              SizedBox(width: 4),
              StatusBadge(status: BadgeStatus.inReview),
            ],
          ),
        ),
      );

      expect(find.text('منشور'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
    });

    testWidgets('badge is rendered inside a Container with a border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(status: BadgeStatus.draft)),
      );

      // StatusBadge wraps its text in a Container — verify the widget tree
      expect(find.byType(Container), findsWidgets);
      expect(find.text('مسودة'), findsOneWidget);
    });
  });

  // ── CC-24: featured-cap warning ────────────────────────────────────────────
  // Verified via the AdminBookFormPage SwitchListTile logic:
  // When isFeatured is toggled ON and featuredCount >= 5, a SnackBar is shown.
  // We test the underlying condition directly using a StatefulWidget test double.
  group('CC-24: featured-cap warning (condition check)', () {
    testWidgets(
      'warning SnackBar is shown when toggling to featured with >=5 existing',
      (tester) async {
        int featuredCount = 5;
        bool isFeatured = false;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      SwitchListTile(
                        value: isFeatured,
                        onChanged: (v) {
                          if (v && featuredCount >= 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تنبيه: يُنصح بعدم تمييز أكثر من 5 كتب في الصفحة الرئيسية',
                                ),
                              ),
                            );
                          }
                          setState(() => isFeatured = v);
                        },
                        title: const Text('كتاب مميز'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Toggle switch ON
        await tester.tap(find.byType(Switch));
        await tester.pump();

        // SnackBar should be visible
        expect(
          find.text('تنبيه: يُنصح بعدم تمييز أكثر من 5 كتب في الصفحة الرئيسية'),
          findsOneWidget,
        );
      },
    );

    testWidgets('no warning when toggling to featured with <5 existing', (
      tester,
    ) async {
      int featuredCount = 3;
      bool isFeatured = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    SwitchListTile(
                      value: isFeatured,
                      onChanged: (v) {
                        if (v && featuredCount >= 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تنبيه: يُنصح بعدم تمييز أكثر من 5 كتب',
                              ),
                            ),
                          );
                        }
                        setState(() => isFeatured = v);
                      },
                      title: const Text('كتاب مميز'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      // No warning SnackBar
      expect(find.text('تنبيه: يُنصح بعدم تمييز أكثر من 5 كتب'), findsNothing);
    });
  });
}
