// lib/core/config/brand.dart
import 'app_config.dart';

abstract final class Brand {
  static String get sheikhName => AppConfig.sheikhName;
  static const String tagline = 'تحت إشراف اللجنة العلمية';
  static const String appName = 'شيخي';
}
