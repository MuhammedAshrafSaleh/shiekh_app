// lib/features/admin/exam/view/admin_exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../models/admin_final_exam_question_entity.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../../../../models/final_exam_settings_entity.dart';
import '../cubit/admin_exam_cubit.dart';
import '../cubit/admin_exam_state.dart';

class AdminExamPage extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const AdminExamPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminExamCubit, AdminExamState>(
      listener: (context, state) {
        if (state is AdminExamError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
        if (state is AdminExamSaved) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حفظ إعدادات الاختبار'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
        }
      },
      builder: (context, state) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text('اختبار: $bookTitle'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      context.read<AdminExamCubit>().load(bookId),
                ),
              ],
              bottom: const TabBar(tabs: [
                Tab(icon: Icon(Icons.settings_outlined), text: 'الإعدادات'),
                Tab(icon: Icon(Icons.list_outlined), text: 'الأسئلة'),
              ]),
            ),
            body: switch (state) {
              AdminExamLoading() =>
                const Center(child: CircularProgressIndicator()),
              AdminExamLoaded() => TabBarView(children: [
                  _SettingsTab(
                    bookId: bookId,
                    settings: state.settings,
                  ),
                  _QuestionsTab(
                    bookId: bookId,
                    questions: state.questions,
                  ),
                ]),
              AdminExamSaving() =>
                const Center(child: CircularProgressIndicator()),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        );
      },
    );
  }
}

// ── Settings Tab ─────────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final String bookId;
  final FinalExamSettingsEntity? settings;

  const _SettingsTab({required this.bookId, required this.settings});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _timeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _attemptsCtrl = TextEditingController();
  bool _isPublished = false;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void didUpdateWidget(_SettingsTab old) {
    super.didUpdateWidget(old);
    if (!_populated) _populate();
  }

  void _populate() {
    final s = widget.settings;
    if (s == null) {
      _timeCtrl.text = '30';
      _passCtrl.text = '70';
      _attemptsCtrl.text = '2';
      _populated = true;
      return;
    }
    _timeCtrl.text = s.timeLimitMinutes.toString();
    _passCtrl.text = s.passingPercentage.toString();
    _attemptsCtrl.text = s.maxAttempts.toString();
    _isPublished = s.isPublished;
    _populated = true;
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _passCtrl.dispose();
    _attemptsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final time = int.tryParse(_timeCtrl.text.trim());
    final pass = int.tryParse(_passCtrl.text.trim());
    final attempts = int.tryParse(_attemptsCtrl.text.trim());
    if (time == null || pass == null || attempts == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى إدخال أرقام صحيحة في جميع الحقول'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (pass < 1 || pass > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('نسبة النجاح يجب أن تكون بين 1 و 100'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    context.read<AdminExamCubit>().saveSettings(
          timeLimitMinutes: time,
          passingPercentage: pass,
          maxAttempts: attempts,
          isPublished: _isPublished,
        );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CC-14: published exam cannot change past attempts
          if (widget.settings?.isPublished == true)
            Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'الاختبار منشور — المحاولات السابقة ثابتة، لكن يمكنك تعديل الإعدادات للمحاولات القادمة.',
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _timeCtrl,
            decoration: const InputDecoration(
              labelText: 'مدة الاختبار (بالدقائق)',
              hintText: '30',
              suffixText: 'دقيقة',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _passCtrl,
            decoration: const InputDecoration(
              labelText: 'نسبة النجاح (%)',
              hintText: '70',
              suffixText: '%',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _attemptsCtrl,
            decoration: const InputDecoration(
              labelText: 'عدد المحاولات المسموحة',
              hintText: '2',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            title: const Text('نشر الاختبار'),
            subtitle: const Text(
                'بعد النشر يصبح الاختبار متاحاً للطلاب الذين أكملوا جميع الدروس'),
            value: _isPublished,
            onChanged: (v) => setState(() => _isPublished = v),
            contentPadding: EdgeInsetsDirectional.zero,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الإعدادات'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

// ── Questions Tab ─────────────────────────────────────────────────────────

class _QuestionsTab extends StatelessWidget {
  final String bookId;
  final List<AdminFinalExamQuestionEntity> questions;

  const _QuestionsTab({required this.bookId, required this.questions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأسئلة (${questions.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('استيراد من البنك'),
                    onPressed: () => _showBankImport(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة سؤال'),
                    onPressed: () => _showQuestionDialog(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        // CC-16: warn if zero questions
        if (questions.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            child: Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('الاختبار لا يحتوي على أسئلة — لن يكون متاحاً للطلاب'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl + AppSpacing.lg,
            ),
            itemCount: questions.length,
            onReorderItem: (oldIndex, newIndex) {
              final questionIds = questions.map((q) => q.id).toList();
              final question = questionIds.removeAt(oldIndex);
              if (newIndex > oldIndex) newIndex -= 1;
              questionIds.insert(newIndex, question);
              context.read<AdminExamCubit>().reorderQuestions(questionIds);
            },
            itemBuilder: (context, i) => _ExamQuestionTile(
              key: ValueKey(questions[i].id),
              question: questions[i],
              index: i + 1,
            ),
          ),
        ),
      ],
    );
  }

  void _showQuestionDialog(BuildContext context,
      {AdminFinalExamQuestionEntity? existing}) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<AdminExamCubit>(),
        child: _ExamQuestionDialog(existing: existing),
      ),
    );
  }

  Future<void> _showBankImport(BuildContext context) async {
    final cubit = context.read<AdminExamCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final bankQuestions = await cubit.getBankQuestions();
    if (!context.mounted) return;
    if (bankQuestions.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('لا توجد أسئلة في بنك دروس هذا الكتاب'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: cubit,
        child: _BankImportDialog(bankQuestions: bankQuestions),
      ),
    );
  }
}

class _ExamQuestionTile extends StatelessWidget {
  final AdminFinalExamQuestionEntity question;
  final int index;

  const _ExamQuestionTile({
    super.key,
    required this.question,
    required this.index,
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
                ReorderableDragStartListener(
                  index: index - 1,
                  child: Icon(Icons.drag_handle,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.sm),
                CircleAvatar(
                    radius: 12,
                    child: Text('$index',
                        style: const TextStyle(fontSize: 11))),
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
                if (question.sourceQuizQuestionId != null)
                  Tooltip(
                    message: 'مستورد من بنك الأسئلة',
                    child: Icon(Icons.link,
                        size: 14,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showDialog(context, question),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: () =>
                      context.read<AdminExamCubit>().deleteQuestion(question.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...choices.map((key) {
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
                        question.choiceLabel(key),
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

  void _showDialog(
      BuildContext context, AdminFinalExamQuestionEntity question) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<AdminExamCubit>(),
        child: _ExamQuestionDialog(existing: question),
      ),
    );
  }
}

class _ExamQuestionDialog extends StatefulWidget {
  final AdminFinalExamQuestionEntity? existing;
  const _ExamQuestionDialog({this.existing});

  @override
  State<_ExamQuestionDialog> createState() => _ExamQuestionDialogState();
}

class _ExamQuestionDialogState extends State<_ExamQuestionDialog> {
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
    final cubit = context.read<AdminExamCubit>();
    if (widget.existing == null) {
      await cubit.addQuestion(
        questionText: q,
        choiceA: a,
        choiceB: b,
        choiceC: c,
        choiceD: d,
        correctChoice: _correct,
      );
    } else {
      await cubit.updateQuestion(
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
    final ctrls = {'a': _aCtrl, 'b': _bCtrl, 'c': _cCtrl, 'd': _dCtrl};
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
                                  controller: ctrls[key],
                                  decoration: InputDecoration(
                                      labelText: 'الخيار ${labels[key]} *'),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء')),
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

class _BankImportDialog extends StatefulWidget {
  final List<AdminQuizQuestionEntity> bankQuestions;
  const _BankImportDialog({required this.bankQuestions});

  @override
  State<_BankImportDialog> createState() => _BankImportDialogState();
}

class _BankImportDialogState extends State<_BankImportDialog> {
  final Set<String> _selected = {};
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('استيراد من بنك الأسئلة'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.bankQuestions.length,
          itemBuilder: (context, i) {
            final q = widget.bankQuestions[i];
            return CheckboxListTile(
              value: _selected.contains(q.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(q.id);
                } else {
                  _selected.remove(q.id);
                }
              }),
              title: Text(q.questionText, maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              dense: true,
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: _importing || _selected.isEmpty
              ? null
              : () async {
                  setState(() => _importing = true);
                  final selected = widget.bankQuestions
                      .where((q) => _selected.contains(q.id))
                      .toList();
                  final nav = Navigator.of(context);
                  await context.read<AdminExamCubit>().importFromBank(selected);
                  if (mounted) nav.pop();
                },
          child: _importing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('استيراد (${_selected.length})'),
        ),
      ],
    );
  }
}
