// lib/features/lesson/view/lesson_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../lesson/data/lesson_repository.dart';
import '../../qa/cubit/qa_cubit.dart';
import '../../qa/data/qa_repository.dart';
import '../../qa/widgets/ask_question_sheet.dart';
import '../cubit/lesson_cubit.dart';
import '../cubit/lesson_state.dart';
import '../widgets/audio_tab.dart';
import '../widgets/pdf_tab.dart';
import '../widgets/quiz_tab.dart';
import '../widgets/video_tab.dart';

class LessonPage extends StatefulWidget {
  final String lessonId;
  final String bookId;

  const LessonPage({
    super.key,
    required this.lessonId,
    required this.bookId,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  @override
  void initState() {
    super.initState();
    context.read<LessonCubit>().loadLesson(widget.lessonId, widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LessonCubit, LessonState>(
      builder: (context, state) {
        return switch (state) {
          LessonInitial() || LessonLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          LessonError(:final message) => Scaffold(
              appBar: AppBar(),
              body: ErrorState(
                message: message,
                onRetry: () => context
                    .read<LessonCubit>()
                    .loadLesson(widget.lessonId, widget.bookId),
              ),
            ),
          LessonLoaded() => _LessonView(
              state: state,
              lessonId: widget.lessonId,
              bookId: widget.bookId,
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _LessonView extends StatelessWidget {
  final LessonLoaded state;
  final String lessonId;
  final String bookId;

  const _LessonView({
    required this.state,
    required this.lessonId,
    required this.bookId,
  });

  void _openAskSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (ctx) => AskQuestionCubit(ctx.read<QaRepository>()),
        child: AskQuestionSheet(
          bookId: bookId,
          lessonId: lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = state.lesson;
    final lessonRepo = context.read<LessonRepository>();

    final tabs = <_TabDef>[
      if (lesson.hasVideo)
        _TabDef(
          label: 'فيديو',
          icon: Icons.play_circle_outline,
          content: VideoTab(
            videoUrl: lesson.videoUrl!,
            initialPositionSeconds: state.lastPositionSeconds,
          ),
        ),
      if (lesson.hasAudio)
        _TabDef(
          label: 'صوت',
          icon: Icons.headphones_outlined,
          content: AudioTab(
            audioUrl: lesson.audioUrl!,
            lessonTitle: lesson.title,
          ),
        ),
      if (lesson.hasPdf)
        _TabDef(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          content: PdfTab(pdfUrl: lesson.pdfUrl!),
        ),
      if (state.hasQuizQuestions)
        _TabDef(
          label: 'اختبار',
          icon: Icons.quiz_outlined,
          content: RepositoryProvider.value(
            value: lessonRepo,
            child: QuizTab(lessonId: lessonId),
          ),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: const Center(child: Text('لا يوجد محتوى لهذا الدرس بعد')),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lesson.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.question_answer_outlined),
              tooltip: 'اسأل سؤالك',
              onPressed: () => _openAskSheet(context),
            ),
          ],
          bottom: TabBar(
            tabs: tabs
                .map((t) => Tab(icon: Icon(t.icon), text: t.label))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: tabs.map((t) => t.content).toList(),
              ),
            ),
            _NextLessonBar(state: state, bookId: bookId),
          ],
        ),
      ),
    );
  }
}

class _NextLessonBar extends StatelessWidget {
  final LessonLoaded state;
  final String bookId;

  const _NextLessonBar({required this.state, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (state.isCompleted) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'مكتمل',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.green,
                    ),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: state.nextLessonId != null
                  ? () {
                      context.read<LessonCubit>().markVideoWatched();
                      context.pushReplacement(
                          '/lessons/${state.nextLessonId}?bookId=$bookId');
                    }
                  : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const Text('الدرس التالي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final Widget content;

  const _TabDef({
    required this.label,
    required this.icon,
    required this.content,
  });
}
