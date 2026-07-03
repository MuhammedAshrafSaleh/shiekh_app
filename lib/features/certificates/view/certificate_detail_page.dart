// lib/features/certificates/view/certificate_detail_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/certificate_entity.dart';
import '../widgets/certificate_pdf_generator.dart';

class CertificateDetailPage extends StatefulWidget {
  final CertificateEntity certificate;
  final String bookTitle;
  final String studentName;

  const CertificateDetailPage({
    super.key,
    required this.certificate,
    required this.bookTitle,
    required this.studentName,
  });

  @override
  State<CertificateDetailPage> createState() => _CertificateDetailPageState();
}

class _CertificateDetailPageState extends State<CertificateDetailPage> {
  bool _isGenerating = false;

  Future<void> _downloadCertificate() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await CertificatePdfGenerator.generate(
        certificate: widget.certificate,
        studentName: widget.studentName,
        bookTitle: widget.bookTitle,
        sheikhName: AppConfig.sheikhName,
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'شهادة_${widget.bookTitle}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء توليد الشهادة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const gold = Color(0xFFD4A017);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شهادة الإتمام'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Certificate preview card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: gold, size: 56),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'شهادة إتمام',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: gold.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'يُشهد بأن الطالب/ة',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.studentName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'قد أتمّ/ت دراسة كتاب',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.bookTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'بدرجة ${widget.certificate.finalScore}٪'
                      '${widget.certificate.gradeLabel != null ? "  (${widget.certificate.gradeLabel})" : ""}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: gold.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاريخ الإصدار',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            Text(
                              '${widget.certificate.issuedAt.year}/${widget.certificate.issuedAt.month.toString().padLeft(2, '0')}/${widget.certificate.issuedAt.day.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'بإشراف',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            Text(
                              AppConfig.sheikhName,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Download/share button
              FilledButton.icon(
                onPressed: _isGenerating ? null : _downloadCertificate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label:
                    Text(_isGenerating ? 'جارٍ التوليد...' : 'مشاركة / تحميل PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
