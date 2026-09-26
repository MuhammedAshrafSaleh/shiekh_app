// lib/features/certificates/view/certificate_detail_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/certificate_border.dart';
import '../../../core/widgets/ornament_divider.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../models/certificate_entity.dart';
import '../widgets/certificate_pdf_generator.dart';

class CertificateDetailPage extends StatefulWidget {
  const CertificateDetailPage({
    super.key,
    required this.certificate,
    required this.bookTitle,
    required this.studentName,
  });

  final CertificateEntity certificate;
  final String bookTitle;
  final String studentName;

  @override
  State<CertificateDetailPage> createState() => _CertificateDetailPageState();
}

class _CertificateDetailPageState extends State<CertificateDetailPage> {
  bool _isGenerating = false;

  String get _grade {
    final score = '${widget.certificate.finalScore}٪';
    final label = widget.certificate.gradeLabel;
    return label != null ? '$score ($label)' : score;
  }

  String get _issuedDate =>
      DateFormat('yyyy/M/d', 'ar').format(widget.certificate.issuedAt);

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ أثناء توليد الشهادة'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperSunk,
      appBar: AppBar(
        title: const Text('شهادة الإتمام'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.inkInvert,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
          child: Column(
            children: [
              // Certificate preview — landscape aspect ratio (A4)
              AspectRatio(
                aspectRatio: 297 / 210,
                child: CertificateBorder(
                  child: _CertificateContent(
                    studentName: widget.studentName,
                    bookTitle: widget.bookTitle,
                    sheikhName: AppConfig.sheikhName,
                    grade: _grade,
                    issuedDate: _issuedDate,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              SheikhyButton.primary(
                label: _isGenerating ? 'جارٍ التوليد...' : 'مشاركة / تحميل PDF',
                onPressed: _isGenerating ? null : _downloadCertificate,
                isLoading: _isGenerating,
                icon: const Icon(Icons.share_outlined, size: 18),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificateContent extends StatelessWidget {
  const _CertificateContent({
    required this.studentName,
    required this.bookTitle,
    required this.sheikhName,
    required this.grade,
    required this.issuedDate,
  });

  final String studentName;
  final String bookTitle;
  final String sheikhName;
  final String grade;
  final String issuedDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bismillah
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.gold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Small gold diamond separator
            SizedBox(
              width: 60,
              child: OrnamentDivider(color: AppColors.gold, motifWidth: 40),
            ),
            const SizedBox(height: 8),

            // Title
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'شهادة إتمام',
                style: AppTextStyles.displaySm.copyWith(
                  color: AppColors.primary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            OrnamentDivider(color: AppColors.gold),
            const SizedBox(height: 10),

            // Attestation line
            Text(
              'تشهد إدارة الأكاديمية بأنَّ الطالب/ة',
              style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Student name + underline
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                studentName,
                style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(height: 1, color: AppColors.gold),
              ),
            ),
            const SizedBox(height: 10),

            // Body
            Text(
              'قد أتمّ/ت بعون الله وتوفيقه دراسة $bookTitle',
              style: AppTextStyles.small.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'بإشراف فضيلة الشيخ $sheikhName',
              style: AppTextStyles.small.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // Footer: التقدير / التاريخ centered together under the last line
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FooterColumn(label: 'التقدير', value: grade),
                const SizedBox(width: AppSpacing.s6),
                _FooterColumn(label: 'التاريخ', value: issuedDate),
              ],
            ),
          ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkFaint,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.reemKufi(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Container(width: 80, height: 1, color: AppColors.gold),
      ],
    );
  }
}
