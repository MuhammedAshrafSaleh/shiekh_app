// lib/features/suggestions/view/suggestion_audio_page.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/suggestion_entity.dart';
import '../../lesson/widgets/audio_tab.dart';

/// Plays a suggestion's Google Drive audio by handing off to the EXISTING
/// lesson [AudioTab] flow in `previewMode` (download-then-play, no lesson/notes/
/// progress side effects). AudioTab owns Drive-URL conversion, the local-file
/// cache check, dio download w/ progress+cancel, and just_audio playback; this
/// page only frames it with a Scaffold + AppBar showing the suggestion title.
class SuggestionAudioPage extends StatelessWidget {
  const SuggestionAudioPage({super.key, required this.suggestion});

  final SuggestionEntity suggestion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          suggestion.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: AudioTab(
          audioUrl: suggestion.contentUrl,
          lessonTitle: suggestion.title,
          initialPositionSeconds: 0,
          previewMode: true,
        ),
      ),
    );
  }
}
