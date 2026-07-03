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

  const AdminBookDashboardPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminStatsCubit, AdminStatsState>(
      listener: (context, state) {
        if (state is AdminStatsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      builder: (context, state) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(bookTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      context.read<AdminStatsCubit>().load(bookId),
                ),
              ],
              bottom: const TabBar(tabs: [
                Tab(icon: Icon(Icons.list_alt_outlined), text: 'الدروس'),
                Tab(icon: Icon(Icons.bar_chart_outlined), text: 'الإحصاءات'),
                Tab(
                    icon: Icon(Icons.question_answer_outlined),
                    text: 'الأسئلة'),
              ]),
            ),
            body: switch (state) {
              AdminStatsLoading() =>
                const Center(child: CircularProgressIndicator()),
              AdminStatsError() => ErrorState(
                  message: state.message,
                  onRetry: () =>
                      context.read<AdminStatsCubit>().load(bookId),
                ),
              AdminStatsLoaded() => TabBarView(
                  children: [
                    _LessonsTab(
                        lessons: state.lessons, bookId: bookId),
                    _StatsTab(stats: state.stats),
                    _QuestionsTab(questions: state.recentQuestions),
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
              onPressed: () =>
                  context.push('/admin/books/$bookId/lessons'),
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
              onPressed: () =>
                  context.push('/admin/books/$bookId/lessons'),
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
          child: Text('$index',
              style: Theme.of(context).textTheme.labelSmall),
        ),
        title: Text(lesson.title),
        trailing: Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
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
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
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
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
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
                  DateFormat('d/M').format(trend[idx].date),
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

    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
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
              q.isAnswered ? 'تمت الإجابة' : 'في الانتظار',
              style: TextStyle(
                color: q.isAnswered ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
