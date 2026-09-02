// lib/features/lesson/widgets/audio_tab.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/drive_url.dart';
import '../../../core/utils/media_duration.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_progress_bar.dart';

// States managed locally — playback is display-only, not business state
enum _AudioStatus { checking, idle, downloading, playing, paused, error }

class AudioTab extends StatefulWidget {
  final String audioUrl;
  final String lessonTitle;

  const AudioTab({
    super.key,
    required this.audioUrl,
    required this.lessonTitle,
  });

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab> {
  final _player = AudioPlayer();
  final _dio = Dio();
  CancelToken? _cancelToken;
  String? _localPath;
  _AudioStatus _status = _AudioStatus.checking;
  double _downloadProgress = 0;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initialize();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (d != null && mounted) {
        Logger('AudioTab').info(
            'raw duration=${d.inSeconds}s formatted=${formatMediaDuration(d)}');
        setState(() => _duration = d);
      }
    });
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        if (s.processingState == ProcessingState.completed) {
          _status = _AudioStatus.paused;
        } else if (s.playing) {
          _status = _AudioStatus.playing;
        } else if (_status == _AudioStatus.playing) {
          _status = _AudioStatus.paused;
        }
      });
    });
  }

  Future<void> _initialize() async {
    final downloadUrl = toDirectDownloadUrl(widget.audioUrl);
    final fileId = _extractFileId(downloadUrl);
    final dir = await getApplicationDocumentsDirectory();
    _localPath = '${dir.path}/audio_$fileId.mp3';

    if (File(_localPath!).existsSync()) {
      await _loadLocalFile();
    } else {
      if (mounted) setState(() => _status = _AudioStatus.idle);
    }
  }

  Future<void> _startDownload() async {
    final downloadUrl = toDirectDownloadUrl(widget.audioUrl);
    await _download(downloadUrl);
  }

  String _extractFileId(String downloadUrl) {
    final match = RegExp(r'id=([^&]+)').firstMatch(downloadUrl);
    return match?.group(1) ?? downloadUrl.hashCode.toString();
  }

  Future<void> _loadLocalFile() async {
    try {
      await _player.setFilePath(_localPath!);
      if (mounted) setState(() => _status = _AudioStatus.paused);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _AudioStatus.error;
          _errorMessage = 'تعذّر تشغيل الملف الصوتي';
        });
      }
    }
  }

  Future<void> _download(String downloadUrl) async {
    if (mounted) setState(() => _status = _AudioStatus.downloading);
    _cancelToken = CancelToken();
    final tmpPath = '$_localPath.tmp';

    try {
      await _dio.download(
        downloadUrl,
        tmpPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0 || !mounted) return;
          setState(() => _downloadProgress = received / total);
        },
      );

      // Verify response is audio (not Google quota HTML)
      final tmp = File(tmpPath);
      if (await tmp.length() < 10000) {
        await tmp.delete();
        if (mounted) {
          setState(() {
            _status = _AudioStatus.error;
            _errorMessage =
                'تجاوز الملف حصة Google Drive اليومية، جرّب لاحقاً';
          });
        }
        return;
      }

      await tmp.rename(_localPath!);
      if (mounted) setState(() => _status = _AudioStatus.paused);
      await _loadLocalFile();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // CC-9: discard partial file on cancel
        final tmp = File(tmpPath);
        if (await tmp.exists()) await tmp.delete();
        if (mounted) setState(() => _status = _AudioStatus.error);
        return;
      }
      if (mounted) {
        setState(() {
          _status = _AudioStatus.error;
          _errorMessage = e.type == DioExceptionType.connectionError
              ? 'لا يوجد اتصال بالإنترنت'
              : 'تعذّر تحميل الملف الصوتي';
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_status == _AudioStatus.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seek(double value) async {
    await _player.seek(
      Duration(seconds: (value * _duration.inSeconds).toInt()),
    );
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() => _status = _AudioStatus.error);
  }

  @override
  void dispose() {
    _player.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _AudioStatus.checking => const _AudioChecking(),
      _AudioStatus.idle => _AudioIdle(
          lessonTitle: widget.lessonTitle,
          onDownload: _startDownload,
        ),
      _AudioStatus.downloading => _DownloadProgress(
          progress: _downloadProgress,
          onCancel: _cancelDownload,
        ),
      _AudioStatus.error => _AudioError(
          message: _errorMessage ?? 'حدث خطأ أثناء التحميل',
          onRetry: _initialize,
        ),
      _ => _AudioPlayer(
          lessonTitle: widget.lessonTitle,
          status: _status,
          position: _position,
          duration: _duration,
          onTogglePlay: _togglePlay,
          onSeek: _seek,
        ),
    };
  }
}

// ── Checking state ────────────────────────────────────────────────────────────

class _AudioChecking extends StatelessWidget {
  const _AudioChecking();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HeadphoneCircle(),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'جاري التحقق...',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

// ── Idle (no local file) ──────────────────────────────────────────────────────

class _AudioIdle extends StatelessWidget {
  final String lessonTitle;
  final VoidCallback onDownload;

  const _AudioIdle({required this.lessonTitle, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _HeadphoneCircle(),
          const SizedBox(height: AppSpacing.s5),
          Text(
            lessonTitle,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            AppConfig.sheikhName,
            style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          SheikhyButton.primary(
            label: 'تحميل الملف الصوتي',
            icon: const Icon(Icons.download_outlined),
            fullWidth: true,
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}

// ── Download progress ─────────────────────────────────────────────────────────

class _DownloadProgress extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;

  const _DownloadProgress({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _HeadphoneCircle(),
          const SizedBox(height: AppSpacing.s5),
          Text(
            'جارٍ تحميل الملف الصوتي...',
            style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s4),
          SheikhyProgressBar(value: progress),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${(progress * 100).toInt()}٪',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          SheikhyButton.text(
            label: 'إلغاء',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _AudioError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AudioError({required this.message, required this.onRetry});

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
              border: Border.all(
                color: AppColors.danger,
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.headset_off_outlined,
              size: 40,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          SheikhyButton.primary(
            label: 'إعادة المحاولة',
            icon: const Icon(Icons.refresh),
            fullWidth: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ── Audio player ──────────────────────────────────────────────────────────────

class _AudioPlayer extends StatelessWidget {
  final String lessonTitle;
  final _AudioStatus status;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;

  const _AudioPlayer({
    required this.lessonTitle,
    required this.status,
    required this.position,
    required this.duration,
    required this.onTogglePlay,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s6,
        AppSpacing.pageGutter,
        AppSpacing.s5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large artwork circle
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.paperSunk,
            ),
            child: Icon(
              Icons.headphones_outlined,
              size: 72,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: AppSpacing.s5),

          // Lesson title
          Text(
            lessonTitle,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: AppSpacing.s2),

          // Sheikh name
          Text(
            AppConfig.sheikhName,
            style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.s5),

          // Seek slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.paperSunk,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: onSeek,
            ),
          ),

          // Time row
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatMediaDuration(position),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: 0,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                Text(
                  formatMediaDuration(duration),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: 0,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s5),

          // Play / pause button (64×64 circle)
          GestureDetector(
            onTap: onTogglePlay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                status == _AudioStatus.playing
                    ? Icons.pause
                    : Icons.play_arrow,
                color: AppColors.inkInvert,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared artwork circle ─────────────────────────────────────────────────────

class _HeadphoneCircle extends StatelessWidget {
  const _HeadphoneCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.paperSunk,
      ),
      child: Icon(
        Icons.headphones_outlined,
        size: 72,
        color: AppColors.primary,
      ),
    );
  }
}
