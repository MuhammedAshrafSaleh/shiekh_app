// lib/features/theme_preview/theme_preview_main.dart
//
// Standalone entrypoint to review the heritage theme in isolation — no Supabase,
// no router, no Bloc. It does NOT touch app.dart or any real screen.
//
// Run:
//   flutter run -t lib/features/theme_preview/theme_preview_main.dart \
//     --dart-define-from-file=dart_define.json
//
// White-label check: run again overriding the primary, e.g.
//   ... --dart-define=PRIMARY_COLOR=0xFF1C3550   (navy)
//   ... --dart-define=PRIMARY_COLOR=0xFF3E2140   (plum)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/theme/sheikhy_theme.dart';
import 'theme_preview_screen.dart';

void main() => runApp(const ThemePreviewApp());

class ThemePreviewApp extends StatelessWidget {
  const ThemePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شيخي — Theme Preview',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: SheikhyTheme.light(),
      home: const ThemePreviewScreen(),
    );
  }
}
