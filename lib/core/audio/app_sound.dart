// lib/core/audio/app_sound.dart
import '../config/app_config.dart';

/// The catalogue of UI sound effects the app can play.
///
/// [splash] and [success] are white-label: their asset paths resolve through
/// [AppConfig] so each sheikh deployment can ship its own voice recordings.
/// The rest are shared across every deployment and map to the bundled files in
/// `assets/sounds/` (exact, case-sensitive filenames — note the mixed
/// `.mp3` / `.wav` extensions, which must not be renamed).
enum AppSound { splash, tap, select, tick, tickUrgent, timeout, success, retry }

extension AppSoundAsset on AppSound {
  /// Full asset path, e.g. `assets/sounds/tap.mp3`.
  ///
  /// Note: `audioplayers`' `AssetSource` is already rooted at `assets/`, so the
  /// sound service strips this prefix before constructing the source — see
  /// [assetSourcePath].
  String get assetPath => switch (this) {
    AppSound.splash => AppConfig.splashSoundAsset,
    AppSound.success => AppConfig.successSoundAsset,
    AppSound.tap => 'assets/sounds/tap.mp3',
    AppSound.select => 'assets/sounds/select.mp3',
    AppSound.tick => 'assets/sounds/tick.mp3',
    AppSound.tickUrgent => 'assets/sounds/tick_urgent.wav',
    AppSound.timeout => 'assets/sounds/timeout.mp3',
    AppSound.retry => 'assets/sounds/retry.wav',
  };

  /// Path relative to the `assets/` root, as required by `AssetSource`.
  String get assetSourcePath {
    const prefix = 'assets/';
    final path = assetPath;
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }
}
