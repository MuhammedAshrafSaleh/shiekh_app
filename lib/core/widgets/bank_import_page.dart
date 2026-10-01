// lib/core/widgets/bank_import_page.dart
//
// Full-screen question-bank import as a two-level drill-down, shared by the
// book-exam and lesson-quiz import scopes:
//   Step 1 — the book's lessons, each with its approved-original count and how
//            many are currently selected from it.
//   Step 2 — one lesson's questions (loaded lazily), with in-lesson search and
//            a select-all toggle. The correct answer is marked; already-added
//            questions show a "تمت الإضافة" badge and are not selectable.
// Selection persists across lessons; a persistent bottom bar imports all in one
// action. Returns the selected List<AdminQuizQuestionEntity> via Navigator.pop,
// or null if discarded (guarded by a confirm dialog when a selection exists).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../../features/admin/shared/data/question_bank_repository.dart';
import '../../models/admin_quiz_question_entity.dart';
import 'bank_import_cubit.dart';
import 'bank_import_state.dart';
import 'sheikhy_button.dart';
import 'sheikhy_checkbox.dart';
import 'sheikhy_empty_state.dart';
import 'sheikhy_search_field.dart';
import 'show_confirm_dialog.dart';

class BankImportPage extends StatelessWidget {
  final String bookId;

  /// When set (lesson-quiz scope), that lesson is hidden from the lessons list
  /// (you can't import a lesson's questions into itself).
  final String? excludeLessonId;

  /// Source ids already imported into the target (from the exam's or lesson's
  /// existing questions). These are marked "تمت الإضافة" and not selectable.
  final Set<String> alreadyAddedSourceIds;

  const BankImportPage({
    super.key,
    required this.bookId,
    required this.alreadyAddedSourceIds,
    this.excludeLessonId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BankImportCubit(context.read<QuestionBankRepository>(), bookId)
            ..loadLessons(),
      child: _BankImportView(
        excludeLessonId: excludeLessonId,
        alreadyAddedSourceIds: alreadyAddedSourceIds,
      ),
    );
  }
}

class _BankImportView extends StatelessWidget {
  final String? excludeLessonId;
  final Set<String> alreadyAddedSourceIds;

  const _BankImportView({
    required this.excludeLessonId,
    required this.alreadyAddedSourceIds,
  });

  Future<void> _handleClose(BuildContext context) async {
    final cubit = context.read<BankImportCubit>();
    final navigator = Navigator.of(context);
    if (cubit.state.selected.isEmpty) {
      navigator.pop();
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: 'تجاهل الأسئلة المختارة؟',
      message: 'لديك أسئلة محددة لم تُستورد بعد. الخروج سيتجاهلها.',
      confirmLabel: 'تجاهل',
      icon: Icons.close,
    );
    if (discard) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BankImportCubit, BankImportState>(
      builder: (context, state) {
        final inLesson = state.currentLessonId != null;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (inLesson) {
              context.read<BankImportCubit>().backToLessons();
            } else {
              await _handleClose(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(inLesson ? 'اختر الأسئلة' : 'استيراد من البنك'),
              leading: inLesson
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'رجوع',
                      onPressed: () =>
                          context.read<BankImportCubit>().backToLessons(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'إلغاء',
                      onPressed: () => _handleClose(context),
                    ),
            ),
            body: inLesson
                ? _QuestionsView(
                    key: ValueKey(state.currentLessonId),
                    alreadyAddedSourceIds: alreadyAddedSourceIds,
                  )
                : _LessonsView(excludeLessonId: excludeLessonId),
            bottomNavigationBar: _ImportBar(selectedCount: state.selectedCount),
          ),
        );
      },
    );
  }
}

// ── Bottom import bar (shown on both views) ────────────────────────────────

class _ImportBar extends StatelessWidget {
  final int selectedCount;
  const _ImportBar({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        // Scaffold.bottomNavigationBar lays its child out with a bounded but
        // full-screen maxHeight; a center-aligned SheikhyButton would expand to
        // fill it. Column(min) gives the button unbounded vertical constraints
        // so it sizes to its intrinsic height.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheikhyButton.primary(
              fullWidth: true,
              label: 'استيراد ($selectedCount)',
              onPressed: selectedCount == 0
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(context.read<BankImportCubit>().state.selectedList),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: lessons list ───────────────────────────────────────────────────

class _LessonsView extends StatelessWidget {
  final String? excludeLessonId;
  const _LessonsView({required this.excludeLessonId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BankImportCubit, BankImportState>(
      builder: (context, state) {
        switch (state.lessonsStatus) {
          case BankLessonsStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case BankLessonsStatus.error:
            return _ErrorRetry(
              message: state.lessonsError ?? 'تعذّر تحميل الدروس',
              onRetry: () => context.read<BankImportCubit>().loadLessons(),
            );
          case BankLessonsStatus.loaded:
            final lessons = state.lessons
                .where((l) => l.lessonId != excludeLessonId)
                .toList();
            if (lessons.isEmpty) {
              return const SheikhyEmptyState(
                icon: Icons.quiz_outlined,
                heading: 'لا توجد أسئلة في البنك',
                subtitle: 'لا توجد أسئلة معتمدة في دروس هذا الكتاب بعد.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              itemCount: lessons.length,
              itemBuilder: (context, i) {
                final l = lessons[i];
                return _LessonTile(
                  title: l.title,
                  approvedCount: l.approvedCount,
                  selectedCount: state.selectedCountForLesson(l.lessonId),
                  onTap: () =>
                      context.read<BankImportCubit>().openLesson(l.lessonId),
                );
              },
            );
        }
      },
    );
  }
}

class _LessonTile extends StatelessWidget {
  final String title;
  final int approvedCount;
  final int selectedCount;
  final VoidCallback onTap;

  const _LessonTile({
    required this.title,
    required this.approvedCount,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = selectedCount > 0
        ? '$approvedCount سؤال • مختار $selectedCount'
        : '$approvedCount سؤال';
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selectedCount > 0
                            ? AppColors.warning
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: selectedCount > 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: one lesson's questions with search + select-all ────────────────

class _QuestionsView extends StatefulWidget {
  final Set<String> alreadyAddedSourceIds;
  const _QuestionsView({super.key, required this.alreadyAddedSourceIds});

  @override
  State<_QuestionsView> createState() => _QuestionsViewState();
}

class _QuestionsViewState extends State<_QuestionsView> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminQuizQuestionEntity> _filtered(List<AdminQuizQuestionEntity> all) {
    final q = _query.trim();
    if (q.isEmpty) return all;
    return all.where((e) => e.questionText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BankImportCubit, BankImportState>(
      builder: (context, state) {
        if (state.questionsStatus == BankQuestionsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.questionsStatus == BankQuestionsStatus.error) {
          return _ErrorRetry(
            message: state.questionsError ?? 'تعذّر تحميل الأسئلة',
            onRetry: () => context.read<BankImportCubit>().openLesson(
              state.currentLessonId!,
            ),
          );
        }

        final filtered = _filtered(state.currentQuestions);
        // Select-all applies only to the visible, not-already-added questions.
        final selectable = filtered
            .where((q) => !widget.alreadyAddedSourceIds.contains(q.id))
            .toList();
        final allSelected =
            selectable.isNotEmpty &&
            selectable.every((q) => state.selected.containsKey(q.id));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SheikhySearchField(
                      controller: _searchCtrl,
                      hintText: 'ابحث في الأسئلة...',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: selectable.isEmpty
                        ? null
                        : () => context
                              .read<BankImportCubit>()
                              .selectAllFiltered(selectable),
                    child: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const SheikhyEmptyState(
                      icon: Icons.search_off_outlined,
                      heading: 'لا نتائج',
                      subtitle: 'لا توجد أسئلة مطابقة لبحثك.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final q = filtered[i];
                        return _BankQuestionCard(
                          question: q,
                          alreadyAdded: widget.alreadyAddedSourceIds.contains(
                            q.id,
                          ),
                          selected: state.selected.containsKey(q.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BankQuestionCard extends StatelessWidget {
  final AdminQuizQuestionEntity question;
  final bool alreadyAdded;
  final bool selected;

  const _BankQuestionCard({
    required this.question,
    required this.alreadyAdded,
    required this.selected,
  });

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
          SheikhyCheckbox(
            value: selected,
            onChanged: (_) => context.read<BankImportCubit>().toggle(question),
            label: Text(question.questionText, style: questionTextStyle),
          ),
        const SizedBox(height: AppSpacing.sm),
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
                            : theme.colorScheme.primary)
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    question.choiceLabel(key),
                    style: TextStyle(
                      color: isCorrect && !alreadyAdded
                          ? theme.colorScheme.primary
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
              : () => context.read<BankImportCubit>().toggle(question),
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

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            SheikhyButton.secondary(
              label: 'إعادة المحاولة',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
