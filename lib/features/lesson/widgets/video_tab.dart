// lib/features/lesson/widgets/video_tab.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_spacing.dart';
import '../cubit/lesson_cubit.dart';

class VideoTab extends StatefulWidget {
  final String videoUrl;
  final int initialPositionSeconds;

  /// When true, the player runs without any progress tracking (no LessonCubit
  /// calls) — used by the admin "preview as student" screen.
  final bool previewMode;

  const VideoTab({
    super.key,
    required this.videoUrl,
    required this.initialPositionSeconds,
    this.previewMode = false,
  });

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  late YoutubePlayerController _controller;
  Timer? _positionTimer;
  bool _watchedThreshold = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);
    if (videoId == null) {
      _controller = YoutubePlayerController.fromVideoId(videoId: '');
      return;
    }
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      startSeconds: widget.initialPositionSeconds.toDouble(),
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        interfaceLanguage: 'ar',
      ),
    );

    if (widget.previewMode) return;

    // Save position every 15 seconds
    _positionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _savePosition();
    });

    // Monitor for 90% completion (rule L)
    _controller.listen((event) {
      _checkWatchedThreshold();
    });
  }

  Future<void> _savePosition() async {
    if (widget.previewMode || !mounted) return;
    try {
      final position = await _controller.currentTime;
      if (mounted) {
        context.read<LessonCubit>().saveVideoPosition(position.toInt());
      }
    } catch (_) {}
  }

  Future<void> _checkWatchedThreshold() async {
    if (widget.previewMode || _watchedThreshold || !mounted) return;
    try {
      final duration = await _controller.duration;
      final position = await _controller.currentTime;
      if (duration > 0 && position / duration >= 0.9) {
        _watchedThreshold = true;
        if (mounted) {
          context.read<LessonCubit>().markVideoWatched();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    if (!widget.previewMode) _savePosition();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);

    if (videoId == null) {
      return _VideoError(
          message: 'رابط الفيديو غير صحيح، تواصل مع الإدارة');
    }

    return Column(
      children: [
        YoutubePlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _VideoError extends StatelessWidget {
  final String message;
  const _VideoError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'يمكنك الاستمرار عبر التبويبات الأخرى',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}
