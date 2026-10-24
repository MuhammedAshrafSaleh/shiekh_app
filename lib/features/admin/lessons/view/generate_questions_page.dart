// lib/features/admin/lessons/view/generate_questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/sheikhy_progress_bar.dart';
import '../../../../models/lesson_entity.dart';
import '../../ai_settings/data/admin_ai_settings_repository.dart';
import '../cubit/generate_questions_cubit.dart';
import '../cubit/generate_questions_state.dart';

/// Where the transcript comes from before questions are generated.
enum _SourceMode { pasteText, youtube, driveAudio }

/// Admin screen: produce quiz questions with AI. The transcript can be pasted
/// directly, or auto-transcribed from the lesson's YouTube video / Drive audio
/// link (a chained two-phase call: transcribe → generate). Generated questions
/// land as ai_review_status='pending' (invisible to students) and must be
/// reviewed later. Pops with `true` on success so the caller can refresh the
/// lesson's question list.
class GenerateQuestionsPage extends StatefulWidget {
  final String lessonId;

  /// The loaded lesson — used to prefill link fields and detect an already-saved
  /// transcript. Nullable so the page still works if it wasn't provided.
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

  // Captured so we can show SnackBars safely after navigation (they outlive
  // this page). Only ever read while the page is live — never in dispose().
  late ScaffoldMessengerState _messenger;
  // Tracks the transcribe→generate transition to fire the "phase 1 done" toast.
  bool _wasTranscribing = false;

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
    // Keep the live difficulty total in sync as the admin types.
    _easyCtrl.addListener(_onInputChanged);
    _mediumCtrl.addListener(_onInputChanged);
    _hardCtrl.addListener(_onInputChanged);
    _checkAiKey();
  }

  Future<void> _checkAiKey() async {
    final result =
        await context.read<AdminAiSettingsRepository>().getGeminiKeyStatus();
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
    // NOTE: never touch ScaffoldMessenger here — clearing/hiding a SnackBar in
    // dispose() calls markNeedsBuild() while the tree is locked and throws.
    // Lingering error SnackBars are dismissed in the listener before we pop, and
    // the retry action self-guards with `mounted`.
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

  bool get _canSubmit {
    // No AI key configured → generation would fail server-side (AI_KEY_MISSING).
    if (_keyChecked && !_keyIsSet) return false;
    final count = _requestedCount;
    if (count == null || count <= 0) return false;
    switch (_mode) {
      case _SourceMode.pasteText:
        return _transcriptCtrl.text.trim().isNotEmpty;
      case _SourceMode.youtube:
        return _youtubeCtrl.text.trim().isNotEmpty;
      case _SourceMode.driveAudio:
        return _driveCtrl.text.trim().isNotEmpty;
    }
  }

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

  void _submit() {
    final shared = _validateShared();
    if (shared == null) return;
    FocusScope.of(context).unfocus();

    final cubit = context.read<GenerateQuestionsCubit>();
    switch (_mode) {
      case _SourceMode.pasteText:
        final transcript = _transcriptCtrl.text.trim();
        if (transcript.isEmpty) return;
        cubit.generate(
          lessonId: widget.lessonId,
          transcriptText: transcript,
          requestedCount: shared.count,
          difficultyMix: shared.mix,
        );
      case _SourceMode.youtube:
      case _SourceMode.driveAudio:
        final isYoutube = _mode == _SourceMode.youtube;
        final url = (isYoutube ? _youtubeCtrl : _driveCtrl).text.trim();
        if (url.isEmpty) return;
        cubit.transcribeAndGenerate(
          lessonId: widget.lessonId,
          sourceType: isYoutube ? 'youtube' : 'drive_audio',
          sourceUrl: url,
          requestedCount: shared.count,
          difficultyMix: shared.mix,
        );
    }
  }

  /// Generate from an already-saved transcript — skips re-transcription (and the
  /// quota slot it would cost).
  void _useSavedTranscript(String transcript) {
    final shared = _validateShared();
    if (shared == null) return;
    FocusScope.of(context).unfocus();
    context.read<GenerateQuestionsCubit>().generate(
      lessonId: widget.lessonId,
      transcriptText: transcript,
      requestedCount: shared.count,
      difficultyMix: shared.mix,
      savedTranscript: transcript,
    );
  }

  /// Show a SnackBar, replacing whatever is currently visible so an older error
  /// banner never lingers behind a new message (e.g. fix input → retry).
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
      listener: (context, state) {
        if (state is GenerateQuestionsTranscribing) {
          _wasTranscribing = true;
        } else if (state is GenerateQuestionsGenerating) {
          // Phase 1 → phase 2 transition: reassure the admin before the long
          // generation spinner.
          if (_wasTranscribing) {
            _wasTranscribing = false;
            _showSnack(
              const SnackBar(
                content: Text(
                  'تم تفريغ المحاضرة بنجاح، جاري الآن توليد الأسئلة...',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else if (state is GenerateQuestionsSuccess) {
          _wasTranscribing = false;
          // Replaces any lingering error banner, then the success toast rides the
          // root messenger so it stays visible after we pop.
          _showSnack(
            SnackBar(
              content: Text(
                'تم توليد ${state.insertedCount} سؤال، بانتظار المراجعة',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is GenerateQuestionsError) {
          _wasTranscribing = false;
          // Non-fatal: keep the inputs so the admin can retry immediately. When a
          // transcript is already saved, the retry action reuses it (no
          // re-transcribe); otherwise it re-runs the current source.
          final saved = state.savedTranscript;
          _showSnack(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: () {
                  // SnackBars outlive the page — do nothing if we're gone.
                  if (!mounted) return;
                  saved != null ? _useSavedTranscript(saved) : _submit();
                },
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isTranscribing = state is GenerateQuestionsTranscribing;
        final isGenerating = state is GenerateQuestionsGenerating;
        final isBusy = isTranscribing || isGenerating;
        final busyProgress = state is GenerateQuestionsTranscribing
            ? state.progress
            : state is GenerateQuestionsGenerating
                ? state.progress
                : 0.0;
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: const Text('توليد أسئلة بالذكاء الاصطناعي')),
          body: isBusy
              ? _BusyView(isTranscribing: isTranscribing, progress: busyProgress)
              : _buildForm(context, state),
          bottomNavigationBar: SafeArea(
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
                  if (!isBusy && _keyChecked && !_keyIsSet) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_off_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'لم يتم ضبط مفتاح الذكاء الاصطناعي. أضِفه من '
                            'الإعدادات ← مفتاح الذكاء الاصطناعي أولاً.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Persistent inline error so it stays readable after the
                  // SnackBar auto-dismisses.
                  if (!isBusy && state is GenerateQuestionsError) ...[
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  FilledButton.icon(
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('توليد الأسئلة'),
                    onPressed: (isBusy || !_canSubmit) ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, GenerateQuestionsState state) {
    final theme = Theme.of(context);
    // Resolve a saved transcript from in-memory error state first (phase-2 failed
    // this session), then fall back to the initially-loaded lesson.
    final inMemory = state is GenerateQuestionsError
        ? state.savedTranscript
        : null;
    final savedTranscript =
        inMemory ??
        ((widget.lesson?.hasSavedTranscript ?? false)
            ? widget.lesson!.transcript
            : null);

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
          if (savedTranscript != null) ...[
            _SavedTranscriptNotice(
              transcript: savedTranscript,
              onUse: () => _useSavedTranscript(savedTranscript),
              messenger: _messenger,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildSourceInput(),
          const SizedBox(height: AppSpacing.md),
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
                child: _DifficultyField(
                  label: 'متوسط',
                  controller: _mediumCtrl,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DifficultyField(label: 'صعب', controller: _hardCtrl),
              ),
            ],
          ),
          // Keyboard-aware spacer so fields stay above the keyboard.
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        ],
      ),
    );
  }

  Widget _buildSourceInput() {
    switch (_mode) {
      case _SourceMode.pasteText:
        return TextField(
          controller: _transcriptCtrl,
          minLines: 8,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'نص المحاضرة *',
            hintText: 'الصق نص المحاضرة هنا',
            alignLabelWithHint: true,
          ),
        );
      case _SourceMode.youtube:
        return TextField(
          controller: _youtubeCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'رابط فيديو يوتيوب *',
            hintText: 'https://youtu.be/...',
            helperText: 'سيتم تفريغ الفيديو تلقائيًا قبل توليد الأسئلة',
          ),
        );
      case _SourceMode.driveAudio:
        return TextField(
          controller: _driveCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'رابط ملف صوت Drive *',
            hintText: 'https://drive.google.com/file/d/...',
            helperText: 'سيتم تنزيل الملف وتفريغه تلقائيًا قبل توليد الأسئلة',
          ),
        );
    }
  }
}

class _SavedTranscriptNotice extends StatelessWidget {
  final String transcript;
  final VoidCallback onUse;
  final ScaffoldMessengerState messenger;

  const _SavedTranscriptNotice({
    required this.transcript,
    required this.onUse,
    required this.messenger,
  });

  Future<void> _viewTranscript(BuildContext context) async {
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
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'يوجد تفريغ محفوظ لهذه المحاضرة',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewTranscript(context),
                    child: const Text('رؤية'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onUse,
                    child: const Text('استخدامه'),
                  ),
                ),
              ],
            ),
          ],
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

class _BusyView extends StatelessWidget {
  /// True during phase one (transcription); false during question generation.
  final bool isTranscribing;

  /// Estimated progress 0.0–1.0, animated by the cubit timer.
  final double progress;

  const _BusyView({required this.isTranscribing, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (progress * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTranscribing
                  ? 'جاري تفريغ المحاضرة...'
                  : 'جاري توليد الأسئلة...',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SheikhyProgressBar(value: progress),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$pct٪',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'قد تستغرق هذه العملية دقيقة أو أكثر، يرجى الانتظار وعدم إغلاق الصفحة',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
