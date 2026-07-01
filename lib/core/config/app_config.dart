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

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
