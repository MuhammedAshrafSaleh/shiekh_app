// lib/features/admin/lessons/view/admin_lesson_preview_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../models/lesson_pdf_entity.dart';
import '../../../lesson/data/lesson_repository.dart';
import '../../../lesson/widgets/audio_tab.dart';
import '../../../lesson/widgets/pdf_list_tab.dart';
import '../../../lesson/widgets/quiz_tab.dart';
import '../../../lesson/widgets/video_tab.dart';

/// Renders a lesson exactly as a student would see it, using the values the
/// admin is currently editing — without saving, switching accounts, or
/// recording any progress. Reuses the student content widgets in preview mode.
class AdminLessonPreviewPage extends StatelessWidget {
  final String title;
  final String? videoUrl;
  final String? audioUrl;

  /// The lesson's PDFs, already ordered — rendered with the SAME widgets as the
  /// student screen (PdfListTab → PdfViewerPage), not a preview-only path.
  final List<LessonPdfEntity> pdfs;
  final bool audioOnly;

  /// Non-null only for a saved lesson.
  final String? lessonId;

  /// Whether the lesson actually has quiz questions. Mirrors the student
  /// screen's `lessonHasQuiz`: the quiz tab is only shown when true, so the
  /// preview never surfaces a tab the student wouldn't see.
  final bool hasQuiz;

  const AdminLessonPreviewPage({
    super.key,
    required this.title,
    required this.audioOnly,
    this.videoUrl,
    this.audioUrl,
    this.pdfs = const [],
    this.lessonId,
    this.hasQuiz = false,
  });

  bool get _hasVideo =>
      !audioOnly && videoUrl != null && videoUrl!.trim().isNotEmpty;
  bool get _hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
  bool get _hasPdf => pdfs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tabs = <_TabDef>[
      if (_hasVideo)
        _TabDef(
          label: 'فيديو',
          icon: Icons.play_circle_outline,
          content: VideoTab(
            videoUrl: videoUrl!.trim(),
            initialPositionSeconds: 0,
            previewMode: true,
          ),
        ),
      if (_hasAudio)
        _TabDef(
          label: 'صوت',
          icon: Icons.headphones_outlined,
          content: AudioTab(
            audioUrl: audioUrl!.trim(),
            lessonTitle: title,
            previewMode: true,
          ),
        ),
      if (_hasPdf)
        _TabDef(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          // Identical to the student screen: a titled list; taps push the same
          // full-screen PdfViewerPage.
          content: PdfListTab(pdfs: pdfs),
        ),
      // Mirror the student's `lessonHasQuiz`: only show the tab when the lesson
      // actually has questions, so the preview never shows a tab the student
      // wouldn't see.
      if (lessonId != null && hasQuiz)
        _TabDef(
          label: 'اختبار',
          icon: Icons.quiz_outlined,
          // Intentionally renders the REAL quiz, not the enrollment gate the
          // student sees when unenrolled: the admin is reviewing content, not
          // testing enrollment. Do not "fix" this into a gate.
          content: RepositoryProvider.value(
            value: context.read<LessonRepository>(),
            child: QuizTab(lessonId: lessonId!, previewMode: true),
          ),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title.isEmpty ? 'معاينة الدرس' : title)),
        body: const Column(
          children: [
            _PreviewBanner(),
            Expanded(
              child: EmptyState(
                icon: Icons.visibility_off_outlined,
                message: 'لا يوجد محتوى للمعاينة بعد',
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title.isEmpty ? 'معاينة الدرس' : title),
          bottom: TabBar(
            tabs: tabs
                .map((t) => Tab(icon: Icon(t.icon), text: t.label))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            const _PreviewBanner(),
            Expanded(
              child: TabBarView(children: tabs.map((t) => t.content).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'معاينة كما يراها الطالب — لا يتم حفظ أي تقدّم',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
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
