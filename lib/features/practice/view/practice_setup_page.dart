// lib/features/practice/view/practice_setup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_card.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../models/practice_attempt_summary_entity.dart';
import '../../../models/practice_eligible_lesson_entity.dart';
import '../cubit/practice_setup_cubit.dart';
import '../cubit/practice_setup_state.dart';
import '../logic/practice_book_grouping.dart';
import '../logic/practice_distribution.dart';
import '../logic/practice_exam_config.dart';

/// Convert Western digits to Arabic-Indic for display consistency.
String _ar(Object n) {
  const w = '0123456789';
  const a = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final i = w.indexOf(c);
    return i >= 0 ? a[i] : c;
  }).join();
}

class PracticeSetupPage extends StatelessWidget {
  const PracticeSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          const SheikhyPageHeader(title: 'اختبر نفسك'),
          Expanded(
            child: BlocBuilder<PracticeSetupCubit, PracticeSetupState>(
              builder: (context, state) {
                if (state is PracticeSetupInitial ||
                    state is PracticeSetupLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is PracticeSetupError) {
                  return SheikhyErrorState(
                    heading: 'تعذّر تحميل الصفحة',
                    message: state.message,
                    onRetry: () => context.read<PracticeSetupCubit>().load(),
                  );
                }
                if (state is PracticeSetupLoaded) {
                  return _LoadedView(state: state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final PracticeSetupLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeSetupCubit>();
    final hasLessons = state.lessons.isNotEmpty;
    final hasHistory = state.history.isNotEmpty;

    // Nothing to practice and no past attempts → single full-page empty state.
    if (!hasLessons && !hasHistory) {
      return const SheikhyEmptyState(
        icon: Icons.quiz_outlined,
        heading: 'لم تُكمل أي اختبار محاضرة بعد',
        subtitle: 'أكمل اختبار محاضرة ثم عُد لتختبر نفسك عبر عدة محاضرات.',
      );
    }

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: CustomScrollView(
        slivers: [
          if (hasLessons) ...[
            _sectionTitle('اختر المحاضرات'),
            _buildBookRows(cubit),
            SliverToBoxAdapter(child: _Controls(state: state)),
          ] else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageGutter),
                child: _Notice(
                  'لا توجد محاضرات متاحة للاختبار حاليًا. يمكنك مراجعة '
                  'امتحاناتك السابقة بالأسفل.',
                ),
              ),
            ),
          if (hasHistory) ...[
            _sectionTitle('امتحاناتي السابقة'),
            SliverList.builder(
              itemCount: state.history.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  0,
                  AppSpacing.pageGutter,
                  AppSpacing.s3,
                ),
                child: _HistoryCard(attempt: state.history[i]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s7)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s5,
        AppSpacing.pageGutter,
        AppSpacing.s3,
      ),
      child: Text(text, style: AppTextStyles.h3.copyWith(color: AppColors.ink)),
    ),
  );

  /// Flattens the book groups (and the lessons of expanded books) into one
  /// lazy SliverList of header / select-all / lesson rows.
  Widget _buildBookRows(PracticeSetupCubit cubit) {
    final rows = <_SetupRow>[];
    for (final group in state.bookGroups) {
      rows.add(_BookHeaderRow(group));
      if (state.expandedBooks.contains(group.bookTitle)) {
        rows.add(_SelectAllRow(group));
        for (final lesson in group.lessons) {
          rows.add(_LessonItemRow(lesson));
        }
      }
    }

    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        switch (row) {
          case _BookHeaderRow(:final group):
            final selectedCount = group.lessonIds
                .where(state.selectedLessonIds.contains)
                .length;
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter,
                0,
                AppSpacing.pageGutter,
                AppSpacing.s3,
              ),
              child: _BookHeader(
                group: group,
                expanded: state.expandedBooks.contains(group.bookTitle),
                selectedCount: selectedCount,
                onTap: () => cubit.toggleBookExpanded(group.bookTitle),
              ),
            );
          case _SelectAllRow(:final group):
            final allSelected = group.lessonIds.every(
              state.selectedLessonIds.contains,
            );
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter + AppSpacing.s4,
                0,
                AppSpacing.pageGutter,
                AppSpacing.s2,
              ),
              child: _SelectAllToggle(
                allSelected: allSelected,
                onPressed: () => allSelected
                    ? cubit.clearBook(group.lessonIds)
                    : cubit.selectAllInBook(group.lessonIds),
              ),
            );
          case _LessonItemRow(:final lesson):
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter + AppSpacing.s4,
                0,
                AppSpacing.pageGutter,
                AppSpacing.s3,
              ),
              child: _LessonTile(
                lesson: lesson,
                selected: state.selectedLessonIds.contains(lesson.lessonId),
                onTap: () => cubit.toggleLesson(lesson.lessonId),
              ),
            );
        }
      },
    );
  }
}

/// A flattened row in the grouped lesson list.
sealed class _SetupRow {}

class _BookHeaderRow extends _SetupRow {
  final PracticeBookGroup group;
  _BookHeaderRow(this.group);
}

class _SelectAllRow extends _SetupRow {
  final PracticeBookGroup group;
  _SelectAllRow(this.group);
}

class _LessonItemRow extends _SetupRow {
  final PracticeEligibleLessonEntity lesson;
  _LessonItemRow(this.lesson);
}

class _BookHeader extends StatelessWidget {
  final PracticeBookGroup group;
  final bool expanded;
  final int selectedCount;
  final VoidCallback onTap;

  const _BookHeader({
    required this.group,
    required this.expanded,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SheikhyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Row(
        children: [
          Icon(
            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.bookTitle,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  group.lessonCount == 1
                      ? 'محاضرة واحدة متاحة'
                      : '${_ar(group.lessonCount)} محاضرات متاحة',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (selectedCount > 0) ...[
            const SizedBox(width: AppSpacing.s2),
            _SelectedBadge(count: selectedCount),
          ],
        ],
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  final int count;
  const _SelectedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        count == 1 ? 'محاضرة واحدة محددة' : '${_ar(count)} محاضرات محددة',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectAllToggle extends StatelessWidget {
  final bool allSelected;
  final VoidCallback onPressed;

  const _SelectAllToggle({required this.allSelected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          allSelected ? Icons.remove_done_rounded : Icons.done_all_rounded,
          size: 18,
        ),
        label: Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final PracticeEligibleLessonEntity lesson;
  final bool selected;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SheikhyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_box_rounded : Icons.check_box_outline_blank,
            color: selected ? AppColors.primary : AppColors.inkFaint,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.lessonTitle,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  lesson.bookTitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          _CountBadge(count: lesson.questionCount),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.paperSunk,
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        '${_ar(count)} سؤال',
        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final PracticeSetupLoaded state;
  const _Controls({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeSetupCubit>();
    final blocked = !state.canStart;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.pageGutter,
        AppSpacing.s4,
        AppSpacing.pageGutter,
        0,
      ),
      child: SheikhyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عدد الأسئلة',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'المتاح: ${_ar(state.totalAvailable)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            if (blocked)
              _Notice(
                'اختار محاضرات أكتر — تحتاج ${_ar(kMinPracticeQuestions)} '
                'سؤالًا على الأقل لبدء الاختبار.',
              )
            else
              _CountSlider(state: state, onChanged: cubit.setCount),
            const Divider(height: AppSpacing.s6, color: AppColors.border),
            _TimerControl(state: state),
            const SizedBox(height: AppSpacing.s4),
            SheikhyButton(
              label: 'ابدأ الاختبار',
              fullWidth: true,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: blocked ? null : () => _onStart(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onStart(BuildContext context) async {
    final config = PracticeExamConfig(
      lessonIds: state.selectedLessonIds.toList(),
      questionCount: state.questionCount,
      timerEnabled: state.timerEnabled,
      timeLimitMinutes: state.timeLimitMinutes,
    );
    // Await the whole practice flow (loading → exam → result). When it pops
    // back here, reload so a just-submitted attempt appears in history without
    // a manual pull-to-refresh.
    await context.push('/practice/loading', extra: config);
    if (context.mounted) context.read<PracticeSetupCubit>().load();
  }
}

class _CountSlider extends StatelessWidget {
  final PracticeSetupLoaded state;
  final ValueChanged<int> onChanged;
  const _CountSlider({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final max = state.maxCount;
    // When the pool is exactly the minimum, the count is fixed at 20.
    if (max <= kMinPracticeQuestions) {
      return Text(
        '${_ar(kMinPracticeQuestions)} سؤالًا',
        style: AppTextStyles.body.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      children: [
        Text(
          _ar(state.questionCount),
          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
        ),
        Slider(
          min: kMinPracticeQuestions.toDouble(),
          max: max.toDouble(),
          divisions: max - kMinPracticeQuestions,
          value: state.questionCount.toDouble(),
          label: _ar(state.questionCount),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _TimerControl extends StatelessWidget {
  final PracticeSetupLoaded state;
  const _TimerControl({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeSetupCubit>();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'مؤقّت الوقت',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(value: state.timerEnabled, onChanged: cubit.toggleTimer),
          ],
        ),
        if (state.timerEnabled) ...[
          Text(
            '${_ar(state.timeLimitMinutes)} دقيقة',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            min: kPracticeTimerMin.toDouble(),
            max: kPracticeTimerMax.toDouble(),
            divisions:
                (kPracticeTimerMax - kPracticeTimerMin) ~/ kPracticeTimerStep,
            value: state.timeLimitMinutes.toDouble(),
            label: _ar(state.timeLimitMinutes),
            onChanged: (v) => cubit.setTimeLimit(v.round()),
          ),
        ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PracticeAttemptSummaryEntity attempt;
  const _HistoryCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final minutes = attempt.durationSeconds ~/ 60;
    final seconds = attempt.durationSeconds % 60;
    final timeTaken =
        '${_ar(minutes)}:${_ar(seconds.toString().padLeft(2, '0'))}';

    return SheikhyCard(
      onTap: () => _onTap(context),
      child: Row(
        children: [
          _ScoreRing(score: attempt.scorePercentage),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relativeTime(attempt.createdAt),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${_ar(attempt.lectureCount)} محاضرات · '
                  '${_ar(attempt.totalCount)} سؤال · $timeTaken',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: AppColors.inkFaint,
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context) {
    context.push('/practice/attempt/${attempt.id}');
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 60 ? AppColors.success : AppColors.gold;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '${_ar(score)}٪',
        style: AppTextStyles.small.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.goldLight),
      ),
      child: Text(
        text,
        style: AppTextStyles.small.copyWith(color: AppColors.goldDeep),
      ),
    );
  }
}
