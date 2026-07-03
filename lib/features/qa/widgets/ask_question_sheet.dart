// lib/features/qa/widgets/ask_question_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_spacing.dart';
import '../cubit/qa_cubit.dart';
import '../cubit/qa_state.dart';

class AskQuestionSheet extends StatefulWidget {
  final String bookId;
  final String lessonId;

  const AskQuestionSheet({
    super.key,
    required this.bookId,
    required this.lessonId,
  });

  @override
  State<AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<AskQuestionSheet> {
  final _controller = TextEditingController();
  static const _maxChars = 500;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<AskQuestionCubit, AskQuestionState>(
      listener: (context, state) {
        if (state is AskQuestionSubmitted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال سؤالك بنجاح'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        if (state is AskQuestionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is AskQuestionSubmitting;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'اسأل سؤالك',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'هويّتك ستظهر للشيخ فقط وتبقى مجهولة للطلاب الآخرين',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final count = value.text.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _controller,
                            maxLength: _maxChars,
                            maxLines: 5,
                            buildCounter: (_, {required currentLength,
                                required isFocused, maxLength}) =>
                                null,
                            decoration: const InputDecoration(
                              hintText: 'اكتب سؤالك هنا...',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$count / $_maxChars',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: count > _maxChars * 0.9
                                  ? colorScheme.error
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final canSubmit =
                          value.text.trim().isNotEmpty && !isSubmitting;
                      return FilledButton.icon(
                        onPressed: canSubmit
                            ? () => context.read<AskQuestionCubit>().submit(
                                  bookId: widget.bookId,
                                  lessonId: widget.lessonId,
                                  questionText: _controller.text.trim(),
                                )
                            : null,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label:
                            const Text('إرسال السؤال'),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
