// lib/features/suggestions/view/suggestion_video_page.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/suggestion_entity.dart';
import '../../lesson/widgets/video_tab.dart';

/// Plays a suggestion's YouTube video in-app by reusing the lesson [VideoTab]
/// player in `previewMode` (no lesson/notes/progress side effects). VideoTab
/// owns loading, invalid-link error, and fullscreen; this page only frames it
/// with a Scaffold + AppBar showing the suggestion title.
class SuggestionVideoPage extends StatelessWidget {
  const SuggestionVideoPage({super.key, required this.suggestion});

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
        child: VideoTab(
          videoUrl: suggestion.contentUrl,
          initialPositionSeconds: 0,
          previewMode: true,
        ),
      ),
    );
  }
}
