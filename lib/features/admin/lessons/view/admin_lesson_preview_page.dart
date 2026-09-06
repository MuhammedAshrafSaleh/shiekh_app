// lib/features/admin/lessons/view/admin_lesson_preview_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../lesson/data/lesson_repository.dart';
import '../../../lesson/widgets/audio_tab.dart';
import '../../../lesson/widgets/pdf_tab.dart';
import '../../../lesson/widgets/quiz_tab.dart';
import '../../../lesson/widgets/video_tab.dart';

/// Renders a lesson exactly as a student would see it, using the values the
/// admin is currently editing — without saving, switching accounts, or
/// recording any progress. Reuses the student content widgets in preview mode.
class AdminLessonPreviewPage extends StatelessWidget {
  final String title;
  final String? videoUrl;
  final String? audioUrl;
  final String? pdfUrl;
  final bool audioOnly;

  /// Non-null only for a saved lesson — enables the quiz preview tab.
  final String? lessonId;

  const AdminLessonPreviewPage({
    super.key,
    required this.title,
    required this.audioOnly,
    this.videoUrl,
    this.audioUrl,
    this.pdfUrl,
    this.lessonId,
  });

  bool get _hasVideo =>
      !audioOnly && videoUrl != null && videoUrl!.trim().isNotEmpty;
  bool get _hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
  bool get _hasPdf => pdfUrl != null && pdfUrl!.trim().isNotEmpty;

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
          content: PdfTab(pdfUrl: pdfUrl!.trim()),
        ),
      if (lessonId != null)
        _TabDef(
          label: 'اختبار',
          icon: Icons.quiz_outlined,
          content: RepositoryProvider.value(
            value: context.read<LessonRepository>(),
            child: QuizTab(lessonId: lessonId!, previewMode: true),
          ),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title.isEmpty ? 'معاينة الدرس' : title),
        ),
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
              child: TabBarView(
                children: tabs.map((t) => t.content).toList(),
              ),
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
