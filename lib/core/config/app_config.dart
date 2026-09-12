// lib/core/config/app_config.dart
import 'package:flutter/material.dart';

abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String sheikhName = String.fromEnvironment(
    'SHEIKH_NAME',
    defaultValue: 'شيخي',
  );

  static const int _primaryColorValue = int.fromEnvironment(
    'PRIMARY_COLOR',
    defaultValue: 0xFF1B5E20,
  );

  static const Color primaryColor = Color(_primaryColorValue);

  // White-label UI sounds: each sheikh can ship his own voice recordings for
  // the splash and success cues. Defaults point at the shared bundled assets.
  // The remaining SFX (tap/select/tick/tick_urgent/timeout/retry) are shared
  // and mapped directly in lib/core/audio/app_sound.dart.
  static const String splashSoundAsset = String.fromEnvironment(
    'SPLASH_SOUND',
    defaultValue: 'assets/sounds/splash.mp3',
  );

  static const String successSoundAsset = String.fromEnvironment(
    'SUCCESS_SOUND',
    defaultValue: 'assets/sounds/success.mp3',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
