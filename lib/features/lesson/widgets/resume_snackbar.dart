// lib/features/lesson/widgets/resume_snackbar.dart
import 'package:flutter/material.dart';

import '../../../core/utils/media_duration.dart';

/// Shows a subtle, auto-dismissing SnackBar telling the student that playback
/// resumed from a saved position (e.g. "استكمال من الدقيقة 3:20").
///
/// Shared by the video and audio players so the wording stays consistent.
void showResumeSnackBar(BuildContext context, int fromSeconds) {
  final label = formatMediaDuration(Duration(seconds: fromSeconds));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('استكمال من الدقيقة $label'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
