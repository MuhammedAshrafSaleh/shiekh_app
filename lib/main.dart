// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/bloc_providers.dart';
import 'core/audio/sound_service.dart';
import 'core/config/app_config.dart';

final _log = Logger('main');

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Draw behind the system bars on all Android versions so the transparent
  // nav bar behaves the same pre-Android-15 as it does under the enforced
  // edge-to-edge mode. Per-screen SafeArea / inset padding keeps content
  // reachable. (Fullscreen video sets its own immersive mode.)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    // ignore: avoid_print
    debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
  });

  assert(
    AppConfig.isConfigured,
    'Run with --dart-define-from-file=dart_define.json',
  );

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    debug: false,
  );

  // Diagnostic only — its result is logged, never consumed. Kept off the
  // startup critical path so a slow network can't delay first paint.
  unawaited(_smokeTestConnection());

  // Kick off SFX preload without blocking first paint. SoundService.play()
  // awaits this in-flight preload, so an early sound (e.g. the splash chime on
  // the first frame) still plays once ready instead of being dropped.
  final soundService = SoundService();
  unawaited(soundService.init());

  FlutterNativeSplash.remove();

  runApp(SheikhyProviders(soundService: soundService));
}

Future<void> _smokeTestConnection() async {
  try {
    await Supabase.instance.client
        .from('books')
        .select('id')
        .limit(1)
        .timeout(const Duration(seconds: 5));
    _log.info('Supabase connection OK');
  } catch (e) {
    _log.warning('Supabase smoke test failed: $e');
  }
}
