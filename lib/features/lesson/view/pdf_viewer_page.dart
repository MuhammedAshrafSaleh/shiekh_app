// lib/features/lesson/view/pdf_viewer_page.dart
import 'package:flutter/material.dart';

import '../widgets/pdf_tab.dart';

/// Full-screen viewer for a single lesson PDF (migration 0012). Pushed from the
/// PDF list when a lesson has multiple PDFs. Reuses [PdfTab] verbatim for the
/// download / render / share / retry logic — this page only adds an AppBar so
/// the title gives context and back returns to the list.
class PdfViewerPage extends StatelessWidget {
  final String title;
  final String url;

  const PdfViewerPage({super.key, required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: PdfTab(pdfUrl: url)),
    );
  }
}
