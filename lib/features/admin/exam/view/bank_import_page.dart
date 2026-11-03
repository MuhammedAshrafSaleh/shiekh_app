// lib/features/admin/exam/view/bank_import_page.dart
//
// Full-screen picker for importing questions from the lesson question bank into
// the book's final exam. Replaces the cramped _BankImportDialog: shows each
// question's full text AND all four choices (correct answer marked), supports
// multi-select, and disables questions already imported (shown with a
// "تمت الإضافة" badge). Returns the selected List<AdminQuizQuestionEntity> via
// Navigator.pop, or null if discarded.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/sheikhy_button.dart';
import '../../../../core/widgets/sheikhy_checkbox.dart';
import '../../../../models/admin_quiz_question_entity.dart';
import '../cubit/bank_import_cubit.dart';

class BankImportPage extends StatelessWidget {
  final List<AdminQuizQuestionEntity> bankQuestions;
  final Set<String> alreadyAddedSourceIds;

  const BankImportPage({
    super.key,
    required this.bankQuestions,
    required this.alreadyAddedSourceIds,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BankImportCubit(),
      child: _BankImportView(
        bankQuestions: bankQuestions,
        alreadyAddedSourceIds: alreadyAddedSourceIds,
      ),
    );
  }
}

class _BankImportView extends StatelessWidget {
  final List<AdminQuizQuestionEntity> bankQuestions;
  final Set<String> alreadyAddedSourceIds;

  const _BankImportView({
    required this.bankQuestions,
    required this.alreadyAddedSourceIds,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد من البنك'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: bankQuestions.isEmpty
          ? const EmptyState(
              icon: Icons.quiz_outlined,
              message: 'لا توجد أسئلة في بنك دروس هذا الكتاب',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    itemCount: bankQuestions.length,
                    itemBuilder: (context, i) {
                      final q = bankQuestions[i];
                      final alreadyAdded = alreadyAddedSourceIds.contains(q.id);
                      return _BankQuestionCard(
                        question: q,
                        alreadyAdded: alreadyAdded,
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: BlocBuilder<BankImportCubit, Set<String>>(
                      builder: (context, selected) {
                        return SheikhyButton.primary(
                          fullWidth: true,
                          label: 'إضافة (${selected.length})',
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  final result = bankQuestions
                                      .where((q) => selected.contains(q.id))
                                      .toList();
                                  Navigator.of(context).pop(result);
                                },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BankQuestionCard extends StatelessWidget {
  final AdminQuizQuestionEntity question;
  final bool alreadyAdded;

  const _BankQuestionCard({required this.question, required this.alreadyAdded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choices = ['a', 'b', 'c', 'd'];

    final questionTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: alreadyAdded ? theme.colorScheme.outline : null,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: checkbox + question text (or a badge + text when already added).
        if (alreadyAdded)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AddedBadge(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(question.questionText, style: questionTextStyle),
              ),
            ],
          )
        else
          BlocBuilder<BankImportCubit, Set<String>>(
            builder: (context, selected) {
              return SheikhyCheckbox(
                value: selected.contains(question.id),
                onChanged: (_) =>
                    context.read<BankImportCubit>().toggle(question.id),
                label: Text(question.questionText, style: questionTextStyle),
              );
            },
          ),
        const SizedBox(height: AppSpacing.sm),
        // Choices with the correct answer marked.
        ...choices.map((key) {
          final isCorrect = question.correctChoice == key;
          final baseColor = alreadyAdded ? theme.colorScheme.outline : null;
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isCorrect
                      ? (alreadyAdded
                            ? theme.colorScheme.outline
                            : AppColors.success)
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    question.choiceLabel(key),
                    style: TextStyle(
                      color: isCorrect && !alreadyAdded
                          ? AppColors.success
                          : baseColor,
                      fontWeight: isCorrect ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );

    return Opacity(
      opacity: alreadyAdded ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: alreadyAdded
              ? null
              : () => context.read<BankImportCubit>().toggle(question.id),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _AddedBadge extends StatelessWidget {
  const _AddedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        'تمت الإضافة',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
