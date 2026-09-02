// lib/features/lesson/widgets/video_tab.dart
import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../cubit/lesson_cubit.dart';
import '../data/video_stream_repository.dart';

/// Plays a YouTube video inline by resolving its direct stream URL (via
/// [VideoStreamRepository]) and playing it with a native [VideoPlayer]/[Chewie].
///
/// Unlike an embedded iframe player, this bypasses the owner's "Allow embedding"
/// restriction (YouTube error 152/101), so unlisted/embedding-disabled videos
/// still play. The stream URL is prefetched + cached by the repository, so the
/// player usually starts without an extraction wait. Muxed streams cap at 360p —
/// acceptable for lecture content.
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

enum _Status { loading, ready, error }

class _VideoTabState extends State<VideoTab> {
  static final _log = Logger('VideoTab');

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _positionTimer;
  bool _watchedThreshold = false;

  _Status _status = _Status.loading;
  bool _invalidUrl = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Resolution is deduped/cached by the repository (usually already prefetched
    // when the lesson opened), so this typically returns instantly.
    final result = await context
        .read<VideoStreamRepository>()
        .resolveStreamUrl(widget.videoUrl);
    if (!mounted) return;

    final url = result.fold((failure) {
      setState(() {
        _status = _Status.error;
        _invalidUrl = failure is ValidationFailure;
      });
      return null;
    }, (url) => url);
    if (url == null) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (widget.initialPositionSeconds > 0) {
        await controller.seekTo(
          Duration(seconds: widget.initialPositionSeconds),
        );
      }
    } on Exception catch (e, s) {
      _log.warning('Failed to init player for ${widget.videoUrl}', e, s);
      await controller.dispose();
      if (mounted) setState(() => _status = _Status.error);
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    _videoController = controller;
    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: false,
      looping: false,
      aspectRatio: 16 / 9,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    if (!widget.previewMode) {
      controller.addListener(_onTick);
      _positionTimer = Timer.periodic(
        const Duration(seconds: 15),
        (p1) => _savePosition(),
      );
    }

    setState(() => _status = _Status.ready);
  }

  /// Called on every player value change — detects the 90% watched threshold.
  void _onTick() {
    if (_watchedThreshold || !mounted) return;
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;
    final total = value.duration.inSeconds;
    if (total <= 0) return;
    if (value.position.inSeconds / total >= 0.9) {
      _watchedThreshold = true;
      context.read<LessonCubit>().markVideoWatched();
    }
  }

  void _savePosition() {
    if (widget.previewMode || !mounted) return;
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;
    context.read<LessonCubit>().saveVideoPosition(value.position.inSeconds);
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.parse(widget.videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _videoController?.removeListener(_onTick);
    _savePosition();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _Status.loading => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      _Status.error => _VideoMessage(
          icon: _invalidUrl
              ? Icons.videocam_off_outlined
              : Icons.smart_display_outlined,
          message: _invalidUrl
              ? 'رابط الفيديو غير صحيح، تواصل مع الإدارة'
              : 'تعذّر تشغيل الفيديو داخل التطبيق. يمكنك مشاهدته على يوتيوب.',
          onOpenYoutube: _invalidUrl ? null : _openInYoutube,
        ),
      _Status.ready => Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Chewie(controller: _chewieController!),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
    };
  }
}

class _VideoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onOpenYoutube;

  const _VideoMessage({
    required this.icon,
    required this.message,
    this.onOpenYoutube,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: AppRadii.rLg,
              border: Border.all(color: AppColors.danger, width: 1.5),
            ),
            child: Icon(icon, size: 40, color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          ),
          if (onOpenYoutube != null) ...[
            const SizedBox(height: AppSpacing.s5),
            SheikhyButton.primary(
              label: 'افتح في يوتيوب',
              icon: const Icon(Icons.open_in_new),
              fullWidth: true,
              onPressed: onOpenYoutube,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          Text(
            'يمكنك الاستمرار عبر التبويبات الأخرى',
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
