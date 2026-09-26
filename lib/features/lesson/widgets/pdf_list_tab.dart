// lib/features/lesson/widgets/pdf_list_tab.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_card.dart';
import '../../../models/lesson_pdf_entity.dart';
import '../view/pdf_viewer_page.dart';

/// The PDF tab content when a lesson has one or more PDFs (migration 0012).
/// Renders a titled list of cards; tapping any card opens the full-screen
/// [PdfViewerPage] for that PDF. A single PDF is simply a one-item list.
class PdfListTab extends StatelessWidget {
  final List<LessonPdfEntity> pdfs;

  const PdfListTab({super.key, required this.pdfs});

  void _open(BuildContext context, LessonPdfEntity pdf) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerPage(title: pdf.title, url: pdf.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pageGutter),
      itemCount: pdfs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
      itemBuilder: (context, index) {
        final pdf = pdfs[index];
        return SheikhyCard(
          padding: const EdgeInsets.all(AppSpacing.s4),
          onTap: () => _open(context, pdf),
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  pdf.title,
                  style: AppTextStyles.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              // App convention for a "drill into row" chevron in this RTL app
              // (points toward the start = forward); see profile_page.dart.
              const Icon(
                Icons.chevron_left,
                color: AppColors.inkFaint,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}
