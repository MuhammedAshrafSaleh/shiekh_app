// lib/features/admin/stats/view/admin_book_dashboard_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../models/lesson_entity.dart';
import '../../../../models/student_question_entity.dart';
import '../cubit/admin_stats_cubit.dart';
import '../cubit/admin_stats_state.dart';
import '../data/admin_stats_repository.dart';

class AdminBookDashboardPage extends StatelessWidget {
  final String bookId;
  final String bookTitle;
  final int initialTab;

  const AdminBookDashboardPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminStatsCubit, AdminStatsState>(
      listener: (context, state) {
        if (state is AdminStatsError) {
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
        final questionCount = state is AdminStatsLoaded
            ? state.questions.length
            : 0;
        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: Text(bookTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<AdminStatsCubit>().load(bookId),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  const Tab(
                    icon: Icon(Icons.list_alt_outlined),
                    text: 'الدروس',
                  ),
                  const Tab(
                    icon: Icon(Icons.bar_chart_outlined),
                    text: 'الإحصاءات',
                  ),
                  Tab(
                    icon: const Icon(Icons.question_answer_outlined),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('الأسئلة'),
                        if (questionCount > 0) ...[
                          const SizedBox(width: AppSpacing.xs),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Text(
                              '$questionCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: switch (state) {
              AdminStatsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              AdminStatsError() => ErrorState(
                message: state.message,
                onRetry: () => context.read<AdminStatsCubit>().load(bookId),
              ),
              AdminStatsLoaded() => TabBarView(
                children: [
                  _LessonsTab(lessons: state.lessons, bookId: bookId),
                  _StatsTab(stats: state.stats),
                  _QuestionsTab(questions: state.questions),
                ],
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        );
      },
    );
  }
}

// ── Lessons Tab ───────────────────────────────────────────────────────────

class _LessonsTab extends StatelessWidget {
  final List<LessonEntity> lessons;
  final String bookId;

  const _LessonsTab({required this.lessons, required this.bookId});

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_lesson_outlined, size: 48),
            const SizedBox(height: AppSpacing.sm),
            const Text('لا توجد دروس بعد'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة درس'),
              onPressed: () => context.push('/admin/books/$bookId/lessons'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      itemCount: lessons.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: FilledButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('إدارة الدروس'),
              onPressed: () => context.push('/admin/books/$bookId/lessons'),
            ),
          );
        }
        final lesson = lessons[i - 1];
        return _LessonSummaryTile(lesson: lesson, index: i);
      },
    );
  }
}

class _LessonSummaryTile extends StatelessWidget {
  final LessonEntity lesson;
  final int index;

  const _LessonSummaryTile({required this.lesson, required this.index});

  @override
  Widget build(BuildContext context) {
    final isPublished = lesson.status == 'published';
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isPublished
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text('$index', style: Theme.of(context).textTheme.labelSmall),
        ),
        title: Text(lesson.title),
        trailing: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isPublished
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isPublished ? 'منشور' : 'مسودة',
            style: TextStyle(
              color: isPublished ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final BookStats stats;

  const _StatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              label: 'إجمالي الطلاب',
              value: stats.totalStudents.toString(),
              icon: Icons.people_outline,
              color: scheme.primary,
            ),
            _StatCard(
              label: 'أتموا الكتاب',
              value: stats.completedStudents.toString(),
              icon: Icons.emoji_events_outlined,
              color: AppColors.gold,
            ),
            _StatCard(
              label: 'معدل الإتمام',
              value: '${stats.completionRate.toStringAsFixed(1)}%',
              icon: Icons.pie_chart_outline,
              color: scheme.primary,
            ),
            _StatCard(
              label: 'متوسط الدرجة',
              value: '${stats.avgScore.toStringAsFixed(1)}%',
              icon: Icons.score_outlined,
              color: stats.avgScore >= 70 ? Colors.green : Colors.orange,
            ),
            _StatCard(
              label: 'محاولات الاختبار',
              value: stats.totalAttempts.toString(),
              icon: Icons.assignment_outlined,
              color: scheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'تسجيلات الطلاب (آخر 30 يوم)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: stats.enrollmentTrend.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : _EnrollmentChart(trend: stats.enrollmentTrend),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentChart extends StatelessWidget {
  final List<EnrollmentPoint> trend;
  const _EnrollmentChart({required this.trend});

  // Hoisted out of the axis-label callback: DateFormat construction is costly
  // and getTitlesWidget is invoked repeatedly during chart layout.
  static final DateFormat _dayMonth = DateFormat('d/M');

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.count.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _dayMonth.format(trend[idx].date),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Questions Tab ─────────────────────────────────────────────────────────

class _QuestionsTab extends StatelessWidget {
  final List<StudentQuestionEntity> questions;
  const _QuestionsTab({required this.questions});

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Center(child: Text('لا توجد أسئلة حتى الآن'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'عدد الأسئلة: ${questions.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('مسح كل الأسئلة'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _confirmClearAll(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: AppSpacing.md,
            ),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              return Card(
                margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: q.isAnswered
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    child: Icon(
                      q.isAnswered
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      color: q.isAnswered ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    q.questionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${q.askerName ?? 'طالب مجهول'} · '
                    '${q.isAnswered ? 'تمت الإجابة' : 'في الانتظار'} · '
                    '${_formatDate(q.createdAt)}',
                    style: TextStyle(
                      color: q.isAnswered ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _openQuestionSheet(context, q),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmClearAll(BuildContext context) {
    final cubit = context.read<AdminStatsCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('مسح كل الأسئلة'),
        content: const Text(
          'هل أنت متأكد من مسح جميع أسئلة هذا الكتاب؟ لا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await cubit.clearBookQuestions();
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم مسح جميع الأسئلة'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('مسح نهائياً'),
          ),
        ],
      ),
    );
  }

  void _openQuestionSheet(BuildContext context, StudentQuestionEntity q) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<AdminStatsCubit>(),
        child: _QuestionSheet(question: q),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}

// ── Question view / edit / delete bottom sheet ──────────────────────────────

class _QuestionSheet extends StatefulWidget {
  final StudentQuestionEntity question;
  const _QuestionSheet({required this.question});

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  late final TextEditingController _answerCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _answerCtrl = TextEditingController(text: widget.question.answerText ?? '');
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final cubit = context.read<AdminStatsCubit>();
    final ok = widget.question.isAnswered
        ? await cubit.editAnswer(
            questionId: widget.question.id,
            answerText: text,
          )
        : await cubit.answerQuestion(
            questionId: widget.question.id,
            answerText: text,
          );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإجابة'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _confirmDelete() {
    final cubit = context.read<AdminStatsCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف السؤال'),
        content: const Text('هل أنت متأكد من حذف هذا السؤال؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await cubit.deleteQuestion(widget.question.id);
              if (!mounted) return;
              Navigator.of(context).pop();
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف السؤال'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  q.askerName ?? 'طالب مجهول',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف السؤال',
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(q.questionText),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'الإجابة',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(hintText: 'اكتب الإجابة...'),
              maxLines: 5,
              autofocus: !q.isAnswered,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(q.isAnswered ? 'حفظ التعديل' : 'إرسال الإجابة'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
