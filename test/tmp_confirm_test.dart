import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/core/audio/sound_service.dart';
import 'package:sheikhy_app/core/widgets/show_confirm_dialog.dart';

void main() {
  testWidgets('showConfirmDialog returns true on confirm, false on cancel', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      RepositoryProvider<SoundService>(
        create: (_) => SoundService(),
        child: MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showConfirmDialog(
                    context,
                    title: 'هل تريد حذف السؤال؟',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    // Cancel path
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('هل تريد حذف السؤال؟'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Confirm path
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
