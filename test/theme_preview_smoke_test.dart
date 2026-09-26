import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/core/theme/sheikhy_theme.dart';
import 'package:sheikhy_app/features/theme_preview/theme_preview_screen.dart';

void main() {
  testWidgets('theme preview renders without overflow at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: SheikhyTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: ThemePreviewScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
