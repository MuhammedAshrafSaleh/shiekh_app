// lib/features/admin/lessons/view/admin_lesson_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bank_import_page.dart';
import '../../../../core/widgets/show_confirm_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/lesson_pdf_entity.dart';
import '../cubit/admin_lesson_cubit.dart';
import '../cubit/admin_lesson_state.dart';
import '../cubit/generate_questions_cubit.dart';
import '../data/admin_lesson_repository.dart';
import 'admin_lesson_preview_page.dart';
import 'generate_questions_page.dart';

class AdminLessonFormPage extends StatefulWidget {
  final String bookId;
  final String? lessonId;

  const AdminLessonFormPage({super.key, required this.bookId, this.lessonId});

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
  bool _audioOnly = false;
  String _status = 'draft';
  bool _populated = false;
  String? _currentLessonId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentLessonId = widget.lessonId;
    context.read<AdminLessonFormCubit>().load(lessonId: widget.lessonId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    _audioCtrl.dispose();
    super.dispose();
  }

  void _populate(LessonEntity lesson) {
    if (_populated) return;
    _populated = true;
    _titleCtrl.text = lesson.title;
    _descCtrl.text = lesson.description ?? '';
    _videoCtrl.text = lesson.videoUrl ?? '';
    _audioCtrl.text = lesson.audioUrl ?? '';
    // PDFs are managed via the PDF tab (state.pdfs), not a text controller.
    _audioOnly = lesson.audioOnly;
    _status = lesson.status;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عنوان الدرس مطلوب'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    await context.read<AdminLessonFormCubit>().save(
      lessonId: widget.lessonId,
      bookId: widget.bookId,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
      audioUrl: _audioCtrl.text.trim().isEmpty ? null : _audioCtrl.text.trim(),
      // No pdfUrl (migration 0012): PDFs are managed via the PDF tab's CRUD, and
      // lessons.pdf_url is a DB-trigger mirror the app never writes.
      audioOnly: _audioOnly,
      status: _status,
    );
  }

  void _openPreview() {
    final video = _videoCtrl.text.trim();
    final audio = _audioCtrl.text.trim();
    // Pass the ordered PDF list so the preview renders exactly like the student
    // screen (PdfListTab). state.pdfs is already sorted; filter empty urls to
    // match the student's LessonEntity.orderedPdfs semantics exactly.
    final state = context.read<AdminLessonFormCubit>().state;
    final pdfs = state is AdminLessonFormLoaded
        ? state.pdfs.where((p) => p.url.isNotEmpty).toList()
        : const <LessonPdfEntity>[];
    // Mirror the student's lessonHasQuiz — the preview quiz tab shows only when
    // the lesson actually has questions.
    final hasQuiz =
        state is AdminLessonFormLoaded && state.quizQuestions.isNotEmpty;
    final hasVideo = !_audioOnly && video.isNotEmpty;
    final hasContent =
        hasVideo ||
        audio.isNotEmpty ||
        pdfs.isNotEmpty ||
        _currentLessonId != null;

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف رابط محتوى أولاً للمعاينة'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminLessonPreviewPage(
          title: _titleCtrl.text.trim(),
          videoUrl: video.isEmpty ? null : video,
          audioUrl: audio.isEmpty ? null : audio,
          pdfs: pdfs,
          audioOnly: _audioOnly,
          lessonId: _currentLessonId,
          hasQuiz: hasQuiz,
        ),
      ),
    );
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
            _audioOnly = state.lesson.audioOnly;
            _status = state.lesson.status;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الدرس بنجاح'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Reload to get quiz questions
          context.read<AdminLessonFormCubit>().load(lessonId: state.lesson.id);
        }
        if (state is AdminLessonFormError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is AdminLessonFormSaving;
        final isLoading = state is AdminLessonFormLoading;
        final quizQuestions = state is AdminLessonFormLoaded
            ? state.quizQuestions
            : const <AdminQuizQuestionEntity>[];
        final pdfs = state is AdminLessonFormLoaded
            ? state.pdfs
            : const <LessonPdfEntity>[];
        final savedLessonId = state is AdminLessonFormLoaded
            ? state.lesson?.id
            : (state is AdminLessonFormSaved ? state.lesson.id : null);
        final currentLessonId = widget.lessonId ?? savedLessonId;
        final bankCount = state is AdminLessonFormLoaded ? state.bankCount : 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.lessonId == null ? 'إضافة درس جديد' : 'تعديل الدرس',
            ),
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
                      onAudioOnlyChanged: (v) => setState(() => _audioOnly = v),
                      onStatusChanged: (v) => setState(() => _status = v!),
                    ),
                    _AudioTab(audioCtrl: _audioCtrl),
                    _PdfTab(lessonId: currentLessonId, pdfs: pdfs),
                    _QuizTab(
                      lessonId: currentLessonId,
                      questions: quizQuestions,
                      bankCount: bankCount,
                    ),
                  ],
                ),
          // Sticky save button (Task 7.1)
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
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

// ── PDF Tab (migration 0012 — multiple PDFs per lesson) ────────────────────
// Mirrors the quiz-questions tab: requires a SAVED lesson to add children, lists
// them with edit/delete + drag-reorder, and manages them via the cubit's CRUD.

class _PdfTab extends StatelessWidget {
  final String? lessonId;
  final List<LessonPdfEntity> pdfs;

  const _PdfTab({required this.lessonId, required this.pdfs});

  @override
  Widget build(BuildContext context) {
    if (lessonId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Text(
            'احفظ الدرس أولاً لإضافة الملفات',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ملفات PDF (${pdfs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة ملف PDF'),
                onPressed: () => _showPdfDialog(context, lessonId: lessonId!),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: pdfs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('لا توجد ملفات PDF بعد'),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: pdfs.length,
                  // onReorderItem already adjusts newIndex for the removed item.
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...pdfs];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    context.read<AdminLessonFormCubit>().reorderLessonPdfs(
                      reordered,
                    );
                  },
                  itemBuilder: (context, i) => _PdfTile(
                    key: ValueKey(pdfs[i].id),
                    pdf: pdfs[i],
                    index: i,
                    lessonId: lessonId!,
                  ),
                ),
        ),
      ],
    );
  }

  static void _showPdfDialog(
    BuildContext context, {
    required String lessonId,
    LessonPdfEntity? existing,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<AdminLessonFormCubit>(),
        child: _PdfDialog(lessonId: lessonId, existing: existing),
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  final LessonPdfEntity pdf;
  final int index; // 0-based position, for the drag handle
  final String lessonId;

  const _PdfTile({
    super.key,
    required this.pdf,
    required this.index,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdf.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    pdf.url,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'تعديل',
              onPressed: () => _PdfTab._showPdfDialog(
                context,
                lessonId: lessonId,
                existing: pdf,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
              tooltip: 'حذف',
              onPressed: () async {
                final cubit = context.read<AdminLessonFormCubit>();
                final ok = await showConfirmDialog(
                  context,
                  title: 'هل تريد حذف الملف؟',
                );
                if (ok) cubit.deleteLessonPdf(pdf.id);
              },
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsetsDirectional.all(AppSpacing.xs),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfDialog extends StatefulWidget {
  final String lessonId;
  final LessonPdfEntity? existing;

  const _PdfDialog({required this.lessonId, this.existing});

  @override
  State<_PdfDialog> createState() => _PdfDialogState();
}

class _PdfDialogState extends State<_PdfDialog> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _titleCtrl.text = p.title;
      _urlCtrl.text = p.url;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    // Title AND url are both required. Rejecting a blank url here is the
    // write-side guard that prevents ever creating an empty-url row.
    if (title.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العنوان والرابط مطلوبان'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<AdminLessonFormCubit>();
    if (widget.existing == null) {
      await cubit.addLessonPdf(
        lessonId: widget.lessonId,
        title: title,
        url: url,
      );
    } else {
      await cubit.updateLessonPdf(
        id: widget.existing!.id,
        title: title,
        url: url,
      );
    }
    if (!mounted) return;
    // Keep the dialog open on failure so the admin's typed title/url isn't lost
    // (the parent form surfaces the error via snackbar). Close only on success.
    if (cubit.state is AdminLessonFormError) {
      setState(() => _saving = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة ملف PDF' : 'تعديل الملف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان الملف *',
                hintText: 'مثال: نص المحاضرة',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'رابط Google Drive *',
                hintText: 'https://drive.google.com/file/d/...',
                prefixIcon: Icon(Icons.picture_as_pdf_outlined),
              ),
              textInputAction: TextInputAction.done,
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
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ── Quiz Tab (Task 7.2) ───────────────────────────────────────────────────

class _QuizTab extends StatelessWidget {
  final String? lessonId;
  final List<AdminQuizQuestionEntity> questions;
  final int bankCount;

  const _QuizTab({
    required this.lessonId,
    required this.questions,
    required this.bankCount,
  });

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

    final pendingCount = questions.where((q) => q.isPendingReview).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أسئلة الاختبار القصير (${questions.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              // Review progress — shown only while AI questions await review.
              if (pendingCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${questions.length - pendingCount} من ${questions.length} سؤال تمت مراجعتها',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (pendingCount > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('الموافقة على الكل'),
                      onPressed: () => _approveAll(context),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text('استيراد من البنك ($bankCount)'),
                    onPressed: bankCount == 0
                        ? null
                        : () => _showBankImport(context),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('توليد بالذكاء الاصطناعي'),
                    onPressed: () => _openGenerate(context, lessonId!),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة سؤال'),
                    onPressed: () =>
                        _showQuestionDialog(context, lessonId: lessonId!),
                  ),
                ],
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
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('لا توجد أسئلة بعد'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
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

  static Future<void> _approveAll(BuildContext context) async {
    final cubit = context.read<AdminLessonFormCubit>();
    final ok = await showConfirmDialog(
      context,
      title: 'الموافقة على كل الأسئلة المعلّقة؟',
    );
    if (ok) cubit.approveAllPending();
  }

  static Future<void> _showBankImport(BuildContext context) async {
    final cubit = context.read<AdminLessonFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final bank = await cubit.getBankQuestions();
    if (!context.mounted) return;
    if (bank.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا توجد أسئلة في دروس هذا الكتاب الأخرى'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final selected = await Navigator.of(context)
        .push<List<AdminQuizQuestionEntity>>(
          MaterialPageRoute(
            builder: (_) => BankImportPage(
              bankQuestions: bank,
              alreadyAddedSourceIds: const {},
            ),
          ),
        );
    if (selected == null || selected.isEmpty) return;
    await cubit.importFromBank(selected);
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

  static Future<void> _openGenerate(
    BuildContext context,
    String lessonId,
  ) async {
    // Capture cubit + repo before awaiting navigation.
    final formCubit = context.read<AdminLessonFormCubit>();
    final repo = context.read<AdminLessonRepository>();
    // Pass the loaded lesson so the generate screen can prefill link fields and
    // detect an already-saved transcript.
    final formState = formCubit.state;
    final lesson = formState is AdminLessonFormLoaded ? formState.lesson : null;
    final generated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BlocProvider<GenerateQuestionsCubit>(
          create: (_) => GenerateQuestionsCubit(repo),
          child: GenerateQuestionsPage(lessonId: lessonId, lesson: lesson),
        ),
      ),
    );
    // On success, refetch so the new pending questions appear in the list.
    if (generated == true) {
      formCubit.load(lessonId: lessonId);
    }
  }
}

enum _QuestionMenuAction { edit, delete }

class _QuestionTile extends StatelessWidget {
  final AdminQuizQuestionEntity question;
  final int index;
  final String lessonId;

  const _QuestionTile({
    required this.question,
    required this.index,
    required this.lessonId,
  });

  void _onMenuAction(BuildContext context, _QuestionMenuAction action) {
    switch (action) {
      case _QuestionMenuAction.edit:
        _QuizTab._showQuestionDialog(
          context,
          lessonId: lessonId,
          existing: question,
        );
      case _QuestionMenuAction.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AdminLessonFormCubit>();
    final ok = await showConfirmDialog(context, title: 'هل تريد حذف السؤال؟');
    if (ok) cubit.deleteQuizQuestion(question.id);
  }

  @override
  Widget build(BuildContext context) {
    final choices = ['a', 'b', 'c', 'd'];
    final isPending = question.isPendingReview;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      // Subtle gold tint distinguishes AI questions awaiting review.
      color: isPending ? AppColors.gold.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPending) ...[
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'AI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const StatusBadge(status: BadgeStatus.inReview),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('$index', style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isPending) ...[
                  // Primary, affirmative action — the normal path for a good
                  // question. Kept visually dominant so it doesn't read as one
                  // half of an approve/reject binary.
                  FilledButton.icon(
                    onPressed: () => context
                        .read<AdminLessonFormCubit>()
                        .approveQuizQuestion(question.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  // Edit / delete live behind an overflow menu so removing a
                  // question is a deliberate, separate step — not a reject.
                  PopupMenuButton<_QuestionMenuAction>(
                    tooltip: 'خيارات',
                    onSelected: (action) => _onMenuAction(context, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _QuestionMenuAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: AppSpacing.sm),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _QuestionMenuAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
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
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'حذف',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...choices.map((key) {
              final label = question.choiceLabel(key);
              final isCorrect = question.correctChoice == key;
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.xs,
                ),
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
            // Review aids for pending AI questions: verify against the quote
            // instead of re-watching the lecture.
            if (isPending &&
                ((question.sourceQuote?.isNotEmpty ?? false) ||
                    (question.explanation?.isNotEmpty ?? false))) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              if (question.sourceQuote?.isNotEmpty ?? false)
                _ReviewNote(
                  label: 'الاقتباس',
                  text: '«${question.sourceQuote!}»',
                ),
              if (question.explanation?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xs),
                _ReviewNote(label: 'الشرح', text: question.explanation!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled review note (quote / explanation) shown under a pending question.
class _ReviewNote extends StatelessWidget {
  final String label;
  final String text;

  const _ReviewNote({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب ملء جميع الحقول'),
          backgroundColor: Colors.orange,
        ),
      );
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
        // Editing a pending AI question also approves it (source=edited_by_admin).
        markReviewed: widget.existing!.isPendingReview,
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
                    .map(
                      (key) => Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: AppSpacing.sm,
                        ),
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
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
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
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
