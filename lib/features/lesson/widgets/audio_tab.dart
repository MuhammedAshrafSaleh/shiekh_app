// lib/features/lesson/widgets/audio_tab.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/drive_url.dart';

// States managed locally — playback is display-only, not business state
enum _AudioStatus { checking, downloading, playing, paused, error }

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
      if (d != null && mounted) setState(() => _duration = d);
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
      await _download(downloadUrl);
    }
  }

  String _extractFileId(String downloadUrl) {
    final match = RegExp(r'id=([^&]+)').firstMatch(downloadUrl);
    return match?.group(1) ?? downloadUrl.hashCode.toString();
  }

  Future<void> _loadLocalFile() async {
    try {
      await _player.setFilePath(_localPath!);
      if (mounted) setState(() => _status = _AudioStatus.paused); // ready to play
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
    await _player.seek(Duration(
        seconds: (value * _duration.inSeconds).toInt()));
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: switch (_status) {
        _AudioStatus.checking => const Center(
            child: CircularProgressIndicator(),
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
      },
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;

  const _DownloadProgress({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.download_outlined, size: 48),
        const SizedBox(height: AppSpacing.md),
        const Text('جارٍ تحميل الملف الصوتي...'),
        const SizedBox(height: AppSpacing.md),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: AppSpacing.sm),
        Text('${(progress * 100).toInt()}%'),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onCancel, child: const Text('إلغاء')),
      ],
    );
  }
}

class _AudioError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AudioError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.headset_off,
            size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }
}

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

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.headphones,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          lessonTitle,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: onSeek,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position), style: theme.textTheme.bodySmall),
              Text(_format(duration), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IconButton.filled(
          onPressed: onTogglePlay,
          iconSize: 40,
          icon: Icon(
            status == _AudioStatus.playing
                ? Icons.pause
                : Icons.play_arrow,
          ),
        ),
      ],
    );
  }
}
