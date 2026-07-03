// lib/features/admin/qa/view/admin_qa_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/student_question_entity.dart';
import '../cubit/admin_qa_cubit.dart';
import '../cubit/admin_qa_state.dart';

class AdminQaPage extends StatelessWidget {
  const AdminQaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminQaCubit, AdminQaState>(
      listener: (context, state) {
        if (state is AdminQaError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('الأسئلة والأجوبة'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<AdminQaCubit>().load(),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('في الانتظار'),
                        if (state is AdminQaLoaded &&
                            state.pending.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            child: Text(
                              '${state.pending.length}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'تمت الإجابة'),
                ],
              ),
            ),
            body: switch (state) {
              AdminQaLoading() =>
                const Center(child: CircularProgressIndicator()),
              AdminQaError() => ErrorState(
                  message: state.message,
                  onRetry: () => context.read<AdminQaCubit>().load(),
                ),
              AdminQaLoaded() => TabBarView(
                  children: [
                    _QuestionsList(
                      questions: state.pending,
                      emptyMessage: 'لا توجد أسئلة في الانتظار',
                      showReply: true,
                    ),
                    _QuestionsList(
                      questions: state.answered,
                      emptyMessage: 'لا توجد أسئلة تمت إجابتها',
                      showReply: false,
                    ),
                  ],
                ),
              _ => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}

class _QuestionsList extends StatelessWidget {
  final List<StudentQuestionEntity> questions;
  final String emptyMessage;
  final bool showReply;

  const _QuestionsList({
    required this.questions,
    required this.emptyMessage,
    required this.showReply,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return EmptyState(
        icon: Icons.question_answer_outlined,
        message: emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AdminQaCubit>().load(),
      child: ListView.builder(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        itemCount: questions.length,
        itemBuilder: (context, i) => _QuestionCard(
          question: questions[i],
          showReply: showReply,
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final StudentQuestionEntity question;
  final bool showReply;

  const _QuestionCard({required this.question, required this.showReply});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'سؤال',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatDate(question.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(question.questionText),
            if (question.answerText != null) ...[
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'الإجابة',
                    style:
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(question.answerText!),
            ],
            if (showReply) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  icon: const Icon(Icons.reply_outlined, size: 16),
                  label: const Text('الإجابة'),
                  onPressed: () => _showReplyDialog(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  void _showReplyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<AdminQaCubit>(),
        child: _ReplyDialog(question: question),
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  final StudentQuestionEntity question;
  const _ReplyDialog({required this.question});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _answerCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final ok = await context.read<AdminQaCubit>().answerQuestion(
          questionId: widget.question.id,
          userId: widget.question.lessonId,
          answerText: text,
        );
    if (mounted) {
      Navigator.of(context).pop();
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت الإجابة بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('الإجابة على السؤال'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.question.questionText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _answerCtrl,
            decoration: const InputDecoration(
              labelText: 'اكتب إجابتك *',
              hintText: 'الإجابة المفصّلة...',
            ),
            maxLines: 5,
            autofocus: true,
          ),
        ],
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
              : const Text('إرسال الإجابة'),
        ),
      ],
    );
  }
}
