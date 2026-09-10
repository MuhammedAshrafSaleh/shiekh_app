// lib/features/lesson/widgets/media_tab.dart

/// Implemented by media tab states (video/audio) so the parent lesson page can
/// pause a player when the student switches to the *other* media tab. Media
/// tabs are kept alive, so playback continues in the background across non-media
/// tabs (quiz/PDF) and only the video↔audio transition pauses the outgoing one.
mixin MediaTabController {
  /// Pause playback now (position is preserved by the live, kept-alive player).
  void pausePlayback();
}
