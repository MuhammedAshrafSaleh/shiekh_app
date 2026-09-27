// lib/features/lesson/widgets/audio_tab.dart
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_progress_bar.dart';
import '../../notes/cubit/notes_cubit.dart';
import '../../notes/cubit/notes_state.dart';
import '../../notes/widgets/note_card.dart';
import '../../notes/widgets/note_editor_sheet.dart';
import '../cubit/lesson_cubit.dart';
import '../data/lesson_repository.dart';
import 'media_tab.dart';
import 'resume_snackbar.dart';

// States managed locally — playback is display-only, not business state
enum _AudioStatus { checking, idle, downloading, playing, paused, error }

class AudioTab extends StatefulWidget {
  final String audioUrl;
  final String lessonTitle;
  final int initialPositionSeconds;
  final String? lessonId;
  final String? bookId;

  /// When set, timestamped notes are enabled for this suggestion audio —
  /// independently of [previewMode]. A `NotesCubit` bound to a suggestion
  /// source must be provided above this widget.
  final String? suggestionId;

  /// When true, the player runs without any progress tracking (no LessonCubit
  /// calls) — used by the admin "preview as student" screen and by suggestion
  /// audio. Note-taking is gated separately (see the notes predicate), so a
  /// suggestion audio can have notes on while progress stays off.
  final bool previewMode;

  const AudioTab({
    super.key,
    required this.audioUrl,
    required this.lessonTitle,
    this.initialPositionSeconds = 0,
    this.lessonId,
    this.bookId,
    this.suggestionId,
    this.previewMode = false,
  });

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab>
    with MediaTabController, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Notes are shown for a suggestion audio (any mode) or for a fully-wired
  /// lesson audio. Decoupled from [previewMode] so suggestion notes work while
  /// position-save/timer/resume stay off. Note: the notes UI lives inside the
  /// loaded player state (`_AudioPlayer`), so it only renders — and its seek
  /// callback only fires — after the file is downloaded and loaded.
  bool get _notesEnabled =>
      widget.suggestionId != null ||
      (!widget.previewMode &&
          widget.lessonId != null &&
          widget.bookId != null);

  final _player = AudioPlayer();
  final _dio = Dio();
  CancelToken? _cancelToken;
  String? _localPath;
  _AudioStatus _status = _AudioStatus.checking;
  double _downloadProgress = 0;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  LessonCubit? _lessonCubit;
  Timer? _positionTimer;
  bool _didShowResumeToast = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.previewMode) {
      _lessonCubit = context.read<LessonCubit>();
    }
  }

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
      // Resume from the saved position, once, when re-entering the lesson.
      if (!widget.previewMode && widget.initialPositionSeconds > 0) {
        await _player.seek(Duration(seconds: widget.initialPositionSeconds));
        if (mounted && !_didShowResumeToast) {
          _didShowResumeToast = true;
          showResumeSnackBar(context, widget.initialPositionSeconds);
        }
      }
      if (mounted) setState(() => _status = _AudioStatus.paused);
      _startPositionTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _AudioStatus.error;
          _errorMessage = 'تعذّر تشغيل الملف الصوتي';
        });
      }
    }
  }

  void _startPositionTimer() {
    if (widget.previewMode || _positionTimer != null) return;
    _positionTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _savePosition(),
    );
  }

  void _savePosition() {
    if (widget.previewMode || !mounted) return;
    // The cubit ignores a position of 0, so we never overwrite real progress.
    _lessonCubit?.savePosition(_player.position.inSeconds, MediaType.audio);
  }

  @override
  void pausePlayback() => _player.pause();

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

  Future<void> _openNoteEditor() async {
    final wasPlaying = _status == _AudioStatus.playing;

    // Note-taking requires an account: a guest is shown the sign-up gate (which
    // carries auto-enroll on conversion) and the note flow aborts. Registered
    // users — enrolled or not — proceed.
    if (!mounted) return;
    final isSuggestion = widget.suggestionId != null;
    if (!AccountGate.guard(
      context,
      returnTo: isSuggestion
          ? '/home'
          : '/lessons/${widget.lessonId}?bookId=${widget.bookId}',
      bookId: widget.bookId,
      guestMessage: isSuggestion
          ? 'أنشئ حساباً لتدوين ملاحظاتك'
          : 'أنشئ حساباً لتدوين ملاحظاتك على الدرس',
    )) {
      return;
    }

    final seconds = _player.position.inSeconds;
    final source = context.read<NotesCubit>().source;
    await _player.pause();

    if (!mounted) return;
    await NoteEditorSheet.show(
      context,
      source: source,
      positionSeconds: seconds,
    );

    if (mounted) context.read<NotesCubit>().refreshAfterEdit();
    if (wasPlaying && mounted) await _player.play();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _savePosition();
    _player.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          onAddNote: _notesEnabled ? _openNoteEditor : null,
          onSeekToNote: _notesEnabled
              ? (seconds) => _player.seek(Duration(seconds: seconds))
              : null,
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
  final VoidCallback? onAddNote;
  final ValueChanged<int>? onSeekToNote;

  const _AudioPlayer({
    required this.lessonTitle,
    required this.status,
    required this.position,
    required this.duration,
    required this.onTogglePlay,
    required this.onSeek,
    this.onAddNote,
    this.onSeekToNote,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s5,
              AppSpacing.pageGutter,
              AppSpacing.s4,
            ),
            child: Column(
              children: [
                // Shrunken artwork circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.paperSunk,
                  ),
                  child: Icon(
                    Icons.headphones_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: AppSpacing.s4),

                Text(
                  lessonTitle,
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: AppSpacing.s2),

                Text(
                  AppConfig.sheikhName,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.s4),

                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.paperSunk,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                  ),
                ),

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

                const SizedBox(height: AppSpacing.s4),

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
          ),
        ),
        if (onAddNote != null) ...[
          SliverToBoxAdapter(
            child: _AddNoteAffordance(onTap: onAddNote!),
          ),
          BlocBuilder<NotesCubit, NotesState>(
            builder: (context, state) {
              if (state is NotesInitial || state is NotesLoading) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: AppSpacing.s4,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }
              if (state is NotesError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.pageGutter,
                      AppSpacing.s2,
                      AppSpacing.pageGutter,
                      AppSpacing.s4,
                    ),
                    child: Text(
                      state.message,
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final notes = (state as NotesLoaded).notes;
              if (notes.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.pageGutter,
                      AppSpacing.s2,
                      AppSpacing.pageGutter,
                      AppSpacing.s4,
                    ),
                    child: Text(
                      'لا توجد ملحوظات لهذه المحاضرة بعد',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkFaint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => NoteCard(
                    note: notes[i],
                    bookId: notes[i].bookId,
                    onSeek: () => onSeekToNote?.call(notes[i].positionSeconds),
                  ),
                  childCount: notes.length,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ── Add-note affordance (mirrors video_tab._AddNoteAffordance) ────────────────

class _AddNoteAffordance extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNoteAffordance({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.pageGutter,
          AppSpacing.s3,
          AppSpacing.pageGutter,
          AppSpacing.s3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.s2),
            Text(
              'إضافة ملحوظة',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ],
        ),
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
