// lib/features/admin/lessons/view/generate_questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/lesson_entity.dart';
import '../../ai_settings/data/admin_ai_settings_repository.dart';
import '../cubit/generate_questions_cubit.dart';
import '../cubit/generate_questions_state.dart';

/// Where the transcript comes from before questions are generated.
enum _SourceMode { pasteText, youtube, driveAudio }

/// Admin screen: produce quiz questions with AI. Under the async-queue contract
/// both AI operations only ENQUEUE a background job and return immediately; this
/// screen is a non-blocking status surface. The admin may leave and return at any
/// time — status is re-read from the database on open and kept live via Realtime
/// (with a 15 s poll fallback).
///
/// Link sources (YouTube / Drive audio) are a two-step flow: تفريغ المحاضرة →
/// wait → when the transcript is ready, توليد الأسئلة. Pasted text skips straight
/// to generation. Generated questions land as ai_review_status='pending'.
class GenerateQuestionsPage extends StatefulWidget {
  final String lessonId;

  /// The loaded lesson — used only to prefill link fields. The authoritative
  /// transcript status comes from the cubit's DB read, not from here.
  final LessonEntity? lesson;

  const GenerateQuestionsPage({super.key, required this.lessonId, this.lesson});

  @override
  State<GenerateQuestionsPage> createState() => _GenerateQuestionsPageState();
}

class _GenerateQuestionsPageState extends State<GenerateQuestionsPage> {
  static const int _maxCount = 15;

  _SourceMode _mode = _SourceMode.pasteText;

  // AI key pre-check: generation needs a key configured (no env fallback). Until
  // checked, we keep the button enabled based on inputs; once checked and found
  // missing, we disable it and show a banner pointing to الإعدادات.
  bool _keyChecked = false;
  bool _keyIsSet = false;

  // Captured so we can show SnackBars safely. Only read while the page is live.
  late ScaffoldMessengerState _messenger;

  // Track terminal-status transitions so the success toast fires exactly once.
  String? _lastTranscriptStatus;
  String? _lastJobStatus;

  final _transcriptCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _driveCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '15');
  final _easyCtrl = TextEditingController(text: '6');
  final _mediumCtrl = TextEditingController(text: '5');
  final _hardCtrl = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    // Prefill link fields from the lesson as a convenience.
    _youtubeCtrl.text = widget.lesson?.videoUrl ?? '';
    _driveCtrl.text = widget.lesson?.audioUrl ?? '';
    // Toggle the submit button's enabled state as the relevant inputs change.
    _transcriptCtrl.addListener(_onInputChanged);
    _youtubeCtrl.addListener(_onInputChanged);
    _driveCtrl.addListener(_onInputChanged);
    _countCtrl.addListener(_onInputChanged);
    _easyCtrl.addListener(_onInputChanged);
    _mediumCtrl.addListener(_onInputChanged);
    _hardCtrl.addListener(_onInputChanged);
    _checkAiKey();
    // Re-derive the true current status from the DB so reopening always shows
    // reality (even after an app restart mid-job).
    context.read<GenerateQuestionsCubit>().load(widget.lessonId);
  }

  Future<void> _checkAiKey() async {
    final result = await context
        .read<AdminAiSettingsRepository>()
        .getGeminiKeyStatus();
    if (!mounted) return;
    setState(() {
      _keyChecked = true;
      _keyIsSet = result.fold((_) => false, (status) => status.isSet);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _transcriptCtrl.dispose();
    _youtubeCtrl.dispose();
    _driveCtrl.dispose();
    _countCtrl.dispose();
    _easyCtrl.dispose();
    _mediumCtrl.dispose();
    _hardCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  int? get _requestedCount => int.tryParse(_countCtrl.text.trim());

  /// Live sum of the three difficulty fields (blank fields count as 0).
  int get _difficultySum =>
      (int.tryParse(_easyCtrl.text.trim()) ?? 0) +
      (int.tryParse(_mediumCtrl.text.trim()) ?? 0) +
      (int.tryParse(_hardCtrl.text.trim()) ?? 0);

  /// Validates the shared count/difficulty inputs. Returns the parsed values, or
  /// null if invalid (a warning is shown).
  ({int count, Map<String, int> mix})? _validateShared() {
    final count = _requestedCount;
    if (count == null || count <= 0) return null;
    if (count > _maxCount) {
      _showWarning('الحد الأقصى لعدد الأسئلة هو $_maxCount');
      return null;
    }
    final easy = int.tryParse(_easyCtrl.text.trim()) ?? 0;
    final medium = int.tryParse(_mediumCtrl.text.trim()) ?? 0;
    final hard = int.tryParse(_hardCtrl.text.trim()) ?? 0;
    if (easy < 0 || medium < 0 || hard < 0) {
      _showWarning('توزيع الصعوبة يجب أن يكون أرقامًا موجبة');
      return null;
    }
    if (easy + medium + hard != count) {
      _showWarning('مجموع الأسئلة حسب الصعوبة يجب أن يساوي العدد المطلوب');
      return null;
    }
    return (count: count, mix: {'easy': easy, 'medium': medium, 'hard': hard});
  }

  void _enqueueTranscription() {
    final isYoutube = _mode == _SourceMode.youtube;
    final url = (isYoutube ? _youtubeCtrl : _driveCtrl).text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<GenerateQuestionsCubit>().enqueueTranscription(
      lessonId: widget.lessonId,
      sourceType: isYoutube ? 'youtube' : 'drive_audio',
      sourceUrl: url,
    );
  }

  /// Enqueue generation using [transcriptText] — the pasted text, or the ready
  /// transcript for a link source.
  void _enqueueGeneration(String transcriptText) {
    final shared = _validateShared();
    if (shared == null) return;
    if (transcriptText.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<GenerateQuestionsCubit>().enqueueGeneration(
      lessonId: widget.lessonId,
      transcriptText: transcriptText.trim(),
      requestedCount: shared.count,
      difficultyMix: shared.mix,
    );
  }

  /// Show a SnackBar, replacing whatever is currently visible so an older banner
  /// never lingers behind a new message.
  void _showSnack(SnackBar bar) {
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(bar);
  }

  void _showWarning(String message) {
    _showSnack(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GenerateQuestionsCubit, GenerateQuestionsState>(
      listenWhen: (prev, curr) =>
          curr is GenerateQuestionsReady || curr is GenerateQuestionsError,
      listener: (context, state) {
        if (state is! GenerateQuestionsReady) return;
        // One-shot enqueue failure.
        if (state.transientError != null) {
          _showSnack(
            SnackBar(
              content: Text(state.transientError!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        // Fire the success toasts only on the transition into a terminal status.
        if (state.transcriptStatus != _lastTranscriptStatus) {
          if (state.transcriptStatus == 'ready' &&
              _lastTranscriptStatus != null) {
            _showSnack(
              const SnackBar(
                content: Text(
                  'تم تفريغ المحاضرة بنجاح، يمكنك الآن توليد الأسئلة',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
          _lastTranscriptStatus = state.transcriptStatus;
        }
        if (state.jobStatus != _lastJobStatus) {
          if (state.jobStatus == 'done' && _lastJobStatus != null) {
            _showSnack(
              SnackBar(
                content: Text(
                  'تم توليد ${state.resultCount ?? 0} سؤال، بانتظار المراجعة',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          _lastJobStatus = state.jobStatus;
        }
      },
      builder: (context, state) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: const Text('توليد أسئلة بالذكاء الاصطناعي')),
          body: switch (state) {
            GenerateQuestionsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            GenerateQuestionsError(:final message) => ErrorState(
              message: message,
              onRetry: () =>
                  context.read<GenerateQuestionsCubit>().load(widget.lessonId),
            ),
            GenerateQuestionsReady() => _buildBody(context, state),
            _ => const SizedBox.shrink(),
          },
          bottomNavigationBar: state is GenerateQuestionsReady
              ? _buildBottomBar(context, state)
              : null,
        );
      },
    );
  }

  // Whether a transcript is available to generate from in the current mode.
  bool _hasTranscriptText(GenerateQuestionsReady state) =>
      _mode == _SourceMode.pasteText
      ? _transcriptCtrl.text.trim().isNotEmpty
      : state.hasTranscript;

  // The transcript text to generate from in the current mode.
  String _transcriptText(GenerateQuestionsReady state) =>
      _mode == _SourceMode.pasteText
      ? _transcriptCtrl.text
      : (state.transcript ?? '');

  // True when the UI is at the generation step (vs. still needing a transcript).
  bool _isGenerationStep(GenerateQuestionsReady state) =>
      _mode == _SourceMode.pasteText || state.hasTranscript;

  Widget _buildBody(BuildContext context, GenerateQuestionsReady state) {
    final theme = Theme.of(context);
    final isGenStep = _isGenerationStep(state);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_SourceMode>(
            segments: const [
              ButtonSegment(
                value: _SourceMode.pasteText,
                label: Text('لصق نص'),
                icon: Icon(Icons.notes),
              ),
              ButtonSegment(
                value: _SourceMode.youtube,
                label: Text('لينك يوتيوب'),
                icon: Icon(Icons.smart_display_outlined),
              ),
              ButtonSegment(
                value: _SourceMode.driveAudio,
                label: Text('لينك صوت Drive'),
                icon: Icon(Icons.audiotrack),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Transcript section ──────────────────────────────────────────
          if (_mode == _SourceMode.pasteText)
            _buildPasteField()
          else
            _buildTranscriptSection(context, state),
          // ── Generation section ──────────────────────────────────────────
          if (isGenStep) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: theme.dividerColor),
            const SizedBox(height: AppSpacing.md),
            if (state.hasTranscript && _mode != _SourceMode.pasteText)
              _TranscriptReadyCard(
                transcript: state.transcript!,
                messenger: _messenger,
              ),
            _buildGenerationInputs(context),
            const SizedBox(height: AppSpacing.md),
            _buildGenerationStatus(context, state),
          ],
          // Keyboard-aware spacer so fields stay above the keyboard.
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        ],
      ),
    );
  }

  Widget _buildPasteField() {
    return TextField(
      controller: _transcriptCtrl,
      minLines: 6,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(
        labelText: 'نص المحاضرة *',
        hintText: 'الصق نص المحاضرة هنا',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildTranscriptSection(
    BuildContext context,
    GenerateQuestionsReady state,
  ) {
    final theme = Theme.of(context);
    final isYoutube = _mode == _SourceMode.youtube;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: isYoutube ? _youtubeCtrl : _driveCtrl,
          keyboardType: TextInputType.url,
          enabled: !state.isTranscriptActive,
          decoration: InputDecoration(
            labelText: isYoutube
                ? 'رابط فيديو يوتيوب *'
                : 'رابط ملف صوت Drive *',
            hintText: isYoutube
                ? 'https://youtu.be/...'
                : 'https://drive.google.com/file/d/...',
            helperText: isYoutube
                ? 'سيتم تفريغ الفيديو قبل توليد الأسئلة'
                : 'سيتم تنزيل الملف وتفريغه قبل توليد الأسئلة',
          ),
        ),
        if (state.isTranscriptActive) ...[
          const SizedBox(height: AppSpacing.md),
          _StatusCard(
            icon: Icons.hourglass_top,
            color: theme.colorScheme.primary,
            title: state.transcriptStatus == 'queued'
                ? 'في الطابور — جاري التفريغ، قد يستغرق وقتًا'
                : 'جاري التفريغ الآن',
            subtitle:
                'يمكنك إغلاق الصفحة والعودة لاحقًا؛ ستكمل العملية في الخلفية.',
            showSpinner: true,
          ),
        ],
        if (state.isTranscriptFailed) ...[
          const SizedBox(height: AppSpacing.md),
          _StatusCard(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            title: 'فشل تفريغ المحاضرة',
            subtitle:
                state.transcriptError ?? 'تعذّر تفريغ المحاضرة، حاول مرة أخرى.',
          ),
        ],
      ],
    );
  }

  Widget _buildGenerationInputs(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _countCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'عدد الأسئلة *',
            hintText: 'مثال: 15',
            helperText: 'الحد الأقصى 15 سؤالًا',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('توزيع الصعوبة', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Builder(
          builder: (context) {
            final target = _requestedCount ?? 0;
            final matches = _difficultySum == target;
            return Text(
              'المجموع: $_difficultySum / $target',
              style: theme.textTheme.bodySmall?.copyWith(
                color: matches ? null : theme.colorScheme.error,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DifficultyField(label: 'سهل', controller: _easyCtrl),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DifficultyField(label: 'متوسط', controller: _mediumCtrl),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DifficultyField(label: 'صعب', controller: _hardCtrl),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenerationStatus(
    BuildContext context,
    GenerateQuestionsReady state,
  ) {
    final theme = Theme.of(context);
    if (state.isJobActive) {
      return _StatusCard(
        icon: Icons.hourglass_top,
        color: theme.colorScheme.primary,
        title: 'في الطابور — جاري توليد الأسئلة',
        subtitle:
            'يمكنك إغلاق الصفحة والعودة لاحقًا؛ ستكمل العملية في الخلفية.',
        showSpinner: true,
      );
    }
    if (state.isJobDone) {
      return _StatusCard(
        icon: Icons.check_circle_outline,
        color: Colors.green,
        title: 'تم توليد ${state.resultCount ?? 0} سؤال، بانتظار المراجعة',
        subtitle: 'ارجع إلى الدرس لمراجعة الأسئلة والموافقة عليها.',
      );
    }
    if (state.isJobFailed) {
      return _StatusCard(
        icon: Icons.error_outline,
        color: theme.colorScheme.error,
        title: 'فشل توليد الأسئلة',
        subtitle: state.jobError ?? 'تعذّر توليد الأسئلة، حاول مرة أخرى.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomBar(BuildContext context, GenerateQuestionsReady state) {
    final theme = Theme.of(context);
    final isGenStep = _isGenerationStep(state);

    // Resolve the single adaptive primary action for the current step.
    final String label;
    final VoidCallback? onPressed;
    final bool busy;
    if (!isGenStep) {
      // Transcription step (link sources, no transcript yet).
      busy = state.isTranscriptActive || state.isSubmitting;
      final url = (_mode == _SourceMode.youtube ? _youtubeCtrl : _driveCtrl)
          .text
          .trim();
      label = state.isTranscriptFailed ? 'إعادة التفريغ' : 'تفريغ المحاضرة';
      final enabled = !busy && url.isNotEmpty && !(_keyChecked && !_keyIsSet);
      onPressed = enabled ? _enqueueTranscription : null;
    } else {
      // Generation step.
      busy = state.isJobActive || state.isSubmitting;
      label = state.isJobFailed ? 'إعادة المحاولة' : 'توليد الأسئلة';
      final count = _requestedCount;
      final enabled =
          !busy &&
          _hasTranscriptText(state) &&
          count != null &&
          count > 0 &&
          !(_keyChecked && !_keyIsSet);
      onPressed = enabled
          ? () => _enqueueGeneration(_transcriptText(state))
          : null;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI key not configured → point the admin to الإعدادات.
            if (_keyChecked && !_keyIsSet) ...[
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_off_outlined,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'لم يتم ضبط مفتاح الذكاء الاصطناعي. أضِفه من '
                      'الإعدادات ← مفتاح الذكاء الاصطناعي أولاً.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            // Midnight-retry hint for a genuine overload failure.
            if (state.transientIsOverload) ...[
              Text(
                'الخدمة مشغولة حالياً. جرّب مرة أخرى بعد منتصف الليل عندما يقل الضغط على الخدمة.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton.icon(
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(label),
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact status card for a queued/running/ready/failed state.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool showSpinner;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSpinner)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a transcript is ready for a link source — confirms it and lets the
/// admin view the full text before generating.
class _TranscriptReadyCard extends StatelessWidget {
  final String transcript;
  final ScaffoldMessengerState messenger;

  const _TranscriptReadyCard({
    required this.transcript,
    required this.messenger,
  });

  Future<void> _view(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('نص التفريغ'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                transcript,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('نسخ'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: transcript));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ النص'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'المحاضرة مُفرَّغة وجاهزة لتوليد الأسئلة',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _view(context),
                child: const Text('رؤية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _DifficultyField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(labelText: label),
    );
  }
}
