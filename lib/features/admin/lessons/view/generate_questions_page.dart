// lib/features/admin/lessons/view/generate_questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../cubit/generate_questions_cubit.dart';
import '../cubit/generate_questions_state.dart';

/// Admin screen: paste a lecture transcript and generate quiz questions with
/// AI. Generated questions land as ai_review_status='pending' (invisible to
/// students) and must be reviewed on a later screen. Pops with `true` on
/// success so the caller can refresh the lesson's question list.
class GenerateQuestionsPage extends StatefulWidget {
  final String lessonId;

  const GenerateQuestionsPage({super.key, required this.lessonId});

  @override
  State<GenerateQuestionsPage> createState() => _GenerateQuestionsPageState();
}

class _GenerateQuestionsPageState extends State<GenerateQuestionsPage> {
  static const int _maxCount = 100;

  final _transcriptCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '25');
  final _easyCtrl = TextEditingController(text: '10');
  final _mediumCtrl = TextEditingController(text: '10');
  final _hardCtrl = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    // Toggle the submit button's enabled state as the required inputs change.
    _transcriptCtrl.addListener(_onInputChanged);
    _countCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _transcriptCtrl.dispose();
    _countCtrl.dispose();
    _easyCtrl.dispose();
    _mediumCtrl.dispose();
    _hardCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  int? get _requestedCount => int.tryParse(_countCtrl.text.trim());

  bool get _canSubmit {
    final count = _requestedCount;
    return _transcriptCtrl.text.trim().isNotEmpty && count != null && count > 0;
  }

  void _submit() {
    final transcript = _transcriptCtrl.text.trim();
    final count = _requestedCount;
    if (transcript.isEmpty || count == null || count <= 0) return;

    if (count > _maxCount) {
      _showWarning('الحد الأقصى لعدد الأسئلة هو $_maxCount');
      return;
    }

    final easy = int.tryParse(_easyCtrl.text.trim()) ?? 0;
    final medium = int.tryParse(_mediumCtrl.text.trim()) ?? 0;
    final hard = int.tryParse(_hardCtrl.text.trim()) ?? 0;
    if (easy < 0 || medium < 0 || hard < 0) {
      _showWarning('توزيع الصعوبة يجب أن يكون أرقامًا موجبة');
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<GenerateQuestionsCubit>().generate(
      lessonId: widget.lessonId,
      transcriptText: transcript,
      requestedCount: count,
      difficultyMix: {'easy': easy, 'medium': medium, 'hard': hard},
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
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
        if (state is GenerateQuestionsSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
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
          // Non-fatal: keep the inputs so the admin can retry immediately.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: _submit,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isGenerating = state is GenerateQuestionsGenerating;
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: const Text('توليد أسئلة بالذكاء الاصطناعي')),
          body: isGenerating ? const _GeneratingView() : _buildForm(context),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: FilledButton.icon(
                icon: isGenerating
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
                onPressed: (isGenerating || !_canSubmit) ? null : _submit,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
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
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _countCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'عدد الأسئلة *',
              hintText: 'مثال: 25',
              helperText:
                  'الحد الأقصى 100 — يُعامل كحدٍّ أعلى، وقد يُولَّد أقل',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('توزيع الصعوبة', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اختياري — لا يلزم أن يساوي مجموعها عدد الأسئلة',
            style: theme.textTheme.bodySmall,
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

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'جاري توليد الأسئلة...',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'قد تستغرق هذه العملية دقيقة أو أكثر، يرجى الانتظار وعدم إغلاق الصفحة',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
