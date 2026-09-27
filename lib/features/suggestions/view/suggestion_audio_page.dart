// lib/features/suggestions/view/suggestion_audio_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/suggestion_entity.dart';
import '../../lesson/widgets/audio_tab.dart';
import '../../notes/cubit/notes_cubit.dart';
import '../../notes/data/notes_source.dart';
import '../../notes/data/suggestion_notes_repository.dart';

/// Plays a suggestion's Google Drive audio via the EXISTING lesson [AudioTab]
/// download-then-play flow in `previewMode` (no position-save/timer/resume).
/// Notes are enabled via [suggestionId] + a suggestion-scoped [NotesCubit]
/// provided here; the notes UI lives inside AudioTab's loaded player state, so
/// seeking to a note only becomes possible once the file has downloaded.
class SuggestionAudioPage extends StatelessWidget {
  const SuggestionAudioPage({super.key, required this.suggestion});

  final SuggestionEntity suggestion;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => NotesCubit(
        SuggestionNotesSource(
          ctx.read<SuggestionNotesRepository>(),
          suggestionId: suggestion.id,
        ),
      )..load(),
      child: Scaffold(
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
            suggestionId: suggestion.id,
            previewMode: true,
          ),
        ),
      ),
    );
  }
}
