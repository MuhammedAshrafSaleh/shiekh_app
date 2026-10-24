// lib/core/audio/sound_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_sound.dart';

/// Plays short UI sound effects (SFX) — taps, quiz ticks, success chimes, etc.
///
/// ## Independence from lesson media (hard requirement)
/// The app plays lesson audio (`just_audio` + `audio_session`) and lesson video
/// (`video_player` / `chewie`) with background playback. SFX must **mix** with
/// that media and must **never** pause, stop, or duck it.
///
/// To guarantee that, this service:
///   * Never touches the global `audio_session` singleton (owned by
///     `just_audio`). It does not import or call `AudioSession` at all.
///   * Configures an [AudioContext] **per SFX player only** so the settings
///     cannot leak into lesson-media playback:
///       - iOS: `ambient` category — silenced by the Ring/Silent switch and
///         mixes with other audio by nature (so no explicit `mixWithOthers`
///         option, which the package only permits on `playback`-family
///         categories).
///       - Android: `AndroidAudioFocus.none` (never request focus → never duck
///         lesson media) with sonification usage/content type.
///
/// ## Latency & overlap
/// One [AudioPlayer] is created per [AppSound] and its source is preloaded at
/// [init], so firing a sound is just `seek(0)` + `resume()`. Distinct sounds
/// live on distinct players, so they never cut each other off.
///
/// ## Failure policy
/// A missing or broken sound file must never crash the app. All load/play work
/// is wrapped in try/catch and logged only in debug builds.
class SoundService with WidgetsBindingObserver {
  static const String _mutedPrefKey = 'sfx_muted';

  final Logger _log = Logger('SoundService');

  final Map<AppSound, AudioPlayer> _players = {};
  bool _muted = false;
  bool _initialized = false;

  /// The in-flight (or completed) preload future. Held so [play] can await it
  /// when a sound is triggered before preload finishes — see [play]. Set once
  /// by [init]; `??=` makes repeat [init] calls idempotent.
  Future<void>? _initFuture;

  bool get isMuted => _muted;

  /// SFX audio context — see the class doc for why these values are used.
  static final AudioContext _sfxContext = AudioContext(
    iOS: AudioContextIOS(
      // `ambient` respects the silent switch and mixes with other audio by
      // default; `mixWithOthers` must NOT be passed here (the package only
      // allows it on playback/playAndRecord/multiRoute categories).
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
    android: const AudioContextAndroid(
      // Never request audio focus → lesson media is never ducked or paused.
      audioFocus: AndroidAudioFocus.none,
      // `media` usage routes to the same audible media stream the lesson
      // player already uses; the earlier `assistanceSonification` usage
      // reported PlayerState.playing but produced NO audible output on device.
      // `focus: none` still guarantees we never duck lesson media. This exact
      // pairing (media + sonification + focus:none) was verified on device:
      // audible tap with zero ducking of concurrent lesson audio.
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
    ),
  );

  /// Preloads every sound and registers the lifecycle observer.
  ///
  /// Kicked off (not necessarily awaited) once at startup. [play] awaits the
  /// returned future when a sound is triggered before preload finishes, so an
  /// early SFX — e.g. the splash chime fired on the first frame — still plays
  /// rather than being silently dropped. Repeat calls return the same future.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedPrefKey) ?? false;
    } catch (e) {
      _logDebug('Failed to read mute preference: $e');
    }

    for (final sound in AppSound.values) {
      try {
        final player = AudioPlayer(playerId: 'sfx_${sound.name}');
        await player.setAudioContext(_sfxContext);
        // Stop (not release) on completion so the preloaded source stays ready
        // for the next play — repeated taps never re-load or cut each other off.
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(sound.assetSourcePath));
        _players[sound] = player;
      } catch (e) {
        _logDebug('Failed to preload ${sound.name} (${sound.assetPath}): $e');
      }
    }

    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  /// Plays [sound] once. No-op when muted or when the sound failed to preload.
  ///
  /// If preload is still in flight (a sound fired before [init] completed),
  /// this awaits it first so the sound is played once ready instead of dropped.
  Future<void> play(AppSound sound) async {
    if (_muted) return;
    // Wait out an in-flight preload so early plays (e.g. the splash chime on
    // the first frame) aren't lost to a not-yet-populated player map.
    if (!_initialized && _initFuture != null) {
      await _initFuture;
    }
    if (_muted) return; // mute may have been set while awaiting preload
    final player = _players[sound];
    if (player == null) return;
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      _logDebug('Failed to play ${sound.name}: $e');
    }
  }

  /// Stops any currently-playing SFX. Never affects lesson media.
  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (e) {
        _logDebug('Failed to stop a sound: $e');
      }
    }
  }

  /// Persists the mute preference. Muting also stops any in-flight SFX.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) await stopAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedPrefKey, muted);
    } catch (e) {
      _logDebug('Failed to persist mute preference: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop SFX when the app is backgrounded. Lesson background audio is a
    // separate engine and is unaffected.
    if (state == AppLifecycleState.paused) {
      stopAll();
    }
  }

  /// Releases all players and removes the lifecycle observer.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (e) {
        _logDebug('Failed to dispose a sound player: $e');
      }
    }
    _players.clear();
    _initialized = false;
    _initFuture = null;
  }

  void _logDebug(String message) {
    if (kDebugMode) _log.warning(message);
  }
}
