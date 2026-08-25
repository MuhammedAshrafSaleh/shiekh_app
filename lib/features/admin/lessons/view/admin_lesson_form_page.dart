// lib/features/admin/lessons/view/admin_lesson_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/lesson_entity.dart';
import '../cubit/admin_lesson_cubit.dart';
import '../cubit/admin_lesson_state.dart';
import 'admin_lesson_preview_page.dart';

class AdminLessonFormPage extends StatefulWidget {
  final String bookId;
  final String? lessonId;

  const AdminLessonFormPage({
    super.key,
    required this.bookId,
    this.lessonId,
  });

  @override
  State<AdminLessonFormPage> createState() => _AdminLessonFormPageState();
}

class _AdminLessonFormPageState extends State<AdminLessonFormPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _audioCtrl = TextEditingController();
  final _pdfCtrl = TextEditingController();
  bool _audioOnly = false;
  String _status = 'draft';
  bool _populated = false;
  String? _currentLessonId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentLessonId = widget.lessonId;
    context
        .read<AdminLessonFormCubit>()
        .load(lessonId: widget.lessonId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    _audioCtrl.dispose();
    _pdfCtrl.dispose();
    super.dispose();
  }

  void _populate(LessonEntity lesson) {
    if (_populated) return;
    _populated = true;
    _titleCtrl.text = lesson.title;
    _descCtrl.text = lesson.description ?? '';
    _videoCtrl.text = lesson.videoUrl ?? '';
    _audioCtrl.text = lesson.audioUrl ?? '';
    _pdfCtrl.text = lesson.pdfUrl ?? '';
    _audioOnly = lesson.audioOnly;
    _status = lesson.status;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('عنوان الدرس مطلوب'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ));
      return;
    }
    await context.read<AdminLessonFormCubit>().save(
          lessonId: widget.lessonId,
          bookId: widget.bookId,
          title: title,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          videoUrl:
              _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          audioUrl:
              _audioCtrl.text.trim().isEmpty ? null : _audioCtrl.text.trim(),
          pdfUrl: _pdfCtrl.text.trim().isEmpty ? null : _pdfCtrl.text.trim(),
          audioOnly: _audioOnly,
          status: _status,
        );
  }

  void _openPreview() {
    final video = _videoCtrl.text.trim();
    final audio = _audioCtrl.text.trim();
    final pdf = _pdfCtrl.text.trim();
    final hasVideo = !_audioOnly && video.isNotEmpty;
    final hasContent = hasVideo ||
        audio.isNotEmpty ||
        pdf.isNotEmpty ||
        _currentLessonId != null;

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أضف رابط محتوى أولاً للمعاينة'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdminLessonPreviewPage(
        title: _titleCtrl.text.trim(),
        videoUrl: video.isEmpty ? null : video,
        audioUrl: audio.isEmpty ? null : audio,
        pdfUrl: pdf.isEmpty ? null : pdf,
        audioOnly: _audioOnly,
        lessonId: _currentLessonId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminLessonFormCubit, AdminLessonFormState>(
      listener: (context, state) {
        if (state is AdminLessonFormLoaded && state.lesson != null) {
          _populate(state.lesson!);
          _currentLessonId = state.lesson!.id;
        }
        if (state is AdminLessonFormSaved) {
          _currentLessonId = state.lesson.id;
          if (!_populated) {
            _populated = true;
            _titleCtrl.text = state.lesson.title;
            _descCtrl.text = state.lesson.description ?? '';
            _videoCtrl.text = state.lesson.videoUrl ?? '';
            _audioCtrl.text = state.lesson.audioUrl ?? '';
            _pdfCtrl.text = state.lesson.pdfUrl ?? '';
            _audioOnly = state.lesson.audioOnly;
            _status = state.lesson.status;
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حفظ الدرس بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
          // Reload to get quiz questions
          context
              .read<AdminLessonFormCubit>()
              .load(lessonId: state.lesson.id);
        }
        if (state is AdminLessonFormError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        final isSaving = state is AdminLessonFormSaving;
        final isLoading = state is AdminLessonFormLoading;
        final quizQuestions = state is AdminLessonFormLoaded
            ? state.quizQuestions
            : const <AdminQuizQuestionEntity>[];
        final savedLessonId = state is AdminLessonFormLoaded
            ? state.lesson?.id
            : (state is AdminLessonFormSaved ? state.lesson.id : null);
        final currentLessonId = widget.lessonId ?? savedLessonId;

        return Scaffold(
          appBar: AppBar(
            title: Text(
                widget.lessonId == null ? 'إضافة درس جديد' : 'تعديل الدرس'),
            actions: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'معاينة كطالب',
                onPressed: _openPreview,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.videocam_outlined), text: 'فيديو'),
                Tab(icon: Icon(Icons.audiotrack_outlined), text: 'صوت'),
                Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
                Tab(icon: Icon(Icons.quiz_outlined), text: 'اختبار'),
              ],
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _VideoTab(
                      titleCtrl: _titleCtrl,
                      descCtrl: _descCtrl,
                      videoCtrl: _videoCtrl,
                      audioOnly: _audioOnly,
                      status: _status,
                      onAudioOnlyChanged: (v) =>
                          setState(() => _audioOnly = v),
                      onStatusChanged: (v) => setState(() => _status = v!),
                    ),
                    _AudioTab(audioCtrl: _audioCtrl),
                    _PdfTab(pdfCtrl: _pdfCtrl),
                    _QuizTab(
                      lessonId: currentLessonId,
                      questions: quizQuestions,
                    ),
                  ],
                ),
          // Sticky save button (Task 7.1)
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ الدرس'),
                onPressed: isSaving ? null : _save,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────

class _VideoTab extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController videoCtrl;
  final bool audioOnly;
  final String status;
  final ValueChanged<bool> onAudioOnlyChanged;
  final ValueChanged<String?> onStatusChanged;

  const _VideoTab({
    required this.titleCtrl,
    required this.descCtrl,
    required this.videoCtrl,
    required this.audioOnly,
    required this.status,
    required this.onAudioOnlyChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'عنوان الدرس *',
              hintText: 'أدخل عنوان الدرس',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'وصف الدرس',
              hintText: 'وصف مختصر (اختياري)',
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: videoCtrl,
            decoration: const InputDecoration(
              labelText: 'رابط الفيديو (يوتيوب)',
              hintText: 'https://youtu.be/...',
              prefixIcon: Icon(Icons.videocam_outlined),
            ),
            enabled: !audioOnly,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            title: const Text('درس صوتي فقط (بدون فيديو)'),
            value: audioOnly,
            onChanged: onAudioOnlyChanged,
            contentPadding: EdgeInsetsDirectional.zero,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('حالة الدرس'),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'draft', label: Text('مسودة')),
              ButtonSegment(value: 'published', label: Text('منشور')),
            ],
            selected: {status},
            onSelectionChanged: (s) => onStatusChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _AudioTab extends StatelessWidget {
  final TextEditingController audioCtrl;
  const _AudioTab({required this.audioCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'رابط Google Drive للملف الصوتي',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'سيتم تحويل الرابط تلقائياً لصيغة التحميل المباشر عند تشغيل الدرس.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: audioCtrl,
            decoration: const InputDecoration(
              labelText: 'رابط الملف الصوتي',
              hintText: 'https://drive.google.com/file/d/...',
              prefixIcon: Icon(Icons.audiotrack_outlined),
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

class _PdfTab extends StatelessWidget {
  final TextEditingController pdfCtrl;
  const _PdfTab({required this.pdfCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'رابط Google Drive لملف PDF',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: pdfCtrl,
            decoration: const InputDecoration(
              labelText: 'رابط ملف PDF',
              hintText: 'https://drive.google.com/file/d/...',
              prefixIcon: Icon(Icons.picture_as_pdf_outlined),
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

// ── Quiz Tab (Task 7.2) ───────────────────────────────────────────────────

class _QuizTab extends StatelessWidget {
  final String? lessonId;
  final List<AdminQuizQuestionEntity> questions;

  const _QuizTab({required this.lessonId, required this.questions});

  @override
  Widget build(BuildContext context) {
    if (lessonId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Text(
            'احفظ الدرس أولاً لإضافة أسئلة الاختبار',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(
            children: [
              Text(
                'أسئلة الاختبار القصير (${questions.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة سؤال'),
                onPressed: () =>
                    _showQuestionDialog(context, lessonId: lessonId!),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 48,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('لا توجد أسئلة بعد'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  itemCount: questions.length,
                  itemBuilder: (context, i) => _QuestionTile(
                    question: questions[i],
                    index: i + 1,
                    lessonId: lessonId!,
                  ),
                ),
        ),
      ],
    );
  }

  static void _showQuestionDialog(
    BuildContext context, {
    required String lessonId,
    AdminQuizQuestionEntity? existing,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<AdminLessonFormCubit>(),
        child: _QuestionDialog(lessonId: lessonId, existing: existing),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final AdminQuizQuestionEntity question;
  final int index;
  final String lessonId;

  const _QuestionTile({
    required this.question,
    required this.index,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context) {
    final choices = ['a', 'b', 'c', 'd'];
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('$index',
                      style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _QuizTab._showQuestionDialog(
                    context,
                    lessonId: lessonId,
                    existing: question,
                  ),
                  tooltip: 'تعديل',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: () =>
                      context.read<AdminLessonFormCubit>().deleteQuizQuestion(question.id),
                  tooltip: 'حذف',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...choices.map((key) {
              final label = question.choiceLabel(key);
              final isCorrect = question.correctChoice == key;
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isCorrect
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isCorrect
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isCorrect ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuestionDialog extends StatefulWidget {
  final String lessonId;
  final AdminQuizQuestionEntity? existing;

  const _QuestionDialog({required this.lessonId, this.existing});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _questionCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();
  final _cCtrl = TextEditingController();
  final _dCtrl = TextEditingController();
  String _correct = 'a';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    if (q != null) {
      _questionCtrl.text = q.questionText;
      _aCtrl.text = q.choiceA;
      _bCtrl.text = q.choiceB;
      _cCtrl.text = q.choiceC;
      _dCtrl.text = q.choiceD;
      _correct = q.correctChoice;
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _aCtrl.dispose();
    _bCtrl.dispose();
    _cCtrl.dispose();
    _dCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _questionCtrl.text.trim();
    final a = _aCtrl.text.trim();
    final b = _bCtrl.text.trim();
    final c = _cCtrl.text.trim();
    final d = _dCtrl.text.trim();
    if (q.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب ملء جميع الحقول'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<AdminLessonFormCubit>();
    if (widget.existing == null) {
      await cubit.addQuizQuestion(
        lessonId: widget.lessonId,
        questionText: q,
        choiceA: a,
        choiceB: b,
        choiceC: c,
        choiceD: d,
        correctChoice: _correct,
      );
    } else {
      await cubit.updateQuizQuestion(
        questionId: widget.existing!.id,
        questionText: q,
        choiceA: a,
        choiceB: b,
        choiceC: c,
        choiceD: d,
        correctChoice: _correct,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controllers = {'a': _aCtrl, 'b': _bCtrl, 'c': _cCtrl, 'd': _dCtrl};
    final labels = {'a': 'أ', 'b': 'ب', 'c': 'ج', 'd': 'د'};

    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة سؤال' : 'تعديل السؤال'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionCtrl,
              decoration: const InputDecoration(labelText: 'نص السؤال *'),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<String>(
              groupValue: _correct,
              onChanged: (v) => setState(() => _correct = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['a', 'b', 'c', 'd']
                    .map((key) => Padding(
                          padding: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Radio<String>(value: key),
                              Expanded(
                                child: TextField(
                                  controller: controllers[key],
                                  decoration: InputDecoration(
                                    labelText: 'الخيار ${labels[key]} *',
                                  ),
                                  textInputAction: key == 'd'
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(top: AppSpacing.xs),
              child: Text(
                'حدد الإجابة الصحيحة بالنقر على الدائرة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
