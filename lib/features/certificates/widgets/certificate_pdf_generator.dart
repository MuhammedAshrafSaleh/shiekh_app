// lib/features/certificates/widgets/certificate_pdf_generator.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../models/certificate_entity.dart';

class CertificatePdfGenerator {
  static Future<List<int>> generate({
    required CertificateEntity certificate,
    required String studentName,
    required String bookTitle,
    required String sheikhName,
  }) async {
    // Cairo is Arabic-capable; Helvetica cannot shape Arabic and renders garbage.
    final base = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold),
    );

    final issuedDate =
        '${certificate.issuedAt.year}/${certificate.issuedAt.month.toString().padLeft(2, '0')}/${certificate.issuedAt.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFD4A017),
                width: 4,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'شهادة إتمام',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 36,
                    color: const PdfColor.fromInt(0xFF1B5E20),
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Certificate of Completion',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColor.fromInt(0xFF555555),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  width: double.infinity,
                  height: 1,
                  color: const PdfColor.fromInt(0xFFD4A017),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'يُشهد بأن الطالب/ة',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColor.fromInt(0xFF555555),
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  studentName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 28,
                    color: const PdfColor.fromInt(0xFF1B5E20),
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'قد أتمّ/ت دراسة كتاب',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColor.fromInt(0xFF555555),
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  bookTitle,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 22,
                    color: const PdfColor.fromInt(0xFF1B5E20),
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'بدرجة  ',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColor.fromInt(0xFF555555),
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      '${certificate.finalScore}٪',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                        color: const PdfColor.fromInt(0xFFD4A017),
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    if (certificate.gradeLabel != null) ...[
                      pw.Text(
                        '  (${certificate.gradeLabel})',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: const PdfColor.fromInt(0xFFD4A017),
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  width: double.infinity,
                  height: 1,
                  color: const PdfColor.fromInt(0xFFD4A017),
                ),
                pw.SizedBox(height: 24),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'تاريخ الإصدار',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColor.fromInt(0xFF888888),
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          issuedDate,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'بإشراف',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColor.fromInt(0xFF888888),
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          sheikhName,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
