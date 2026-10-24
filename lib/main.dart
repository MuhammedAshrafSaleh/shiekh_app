// lib/main.dart
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

  await _smokeTestConnection();

  // Preload UI sound effects before the first frame. Failures here are
  // swallowed inside the service and must never block startup.
  final soundService = SoundService();
  await soundService.init();

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
