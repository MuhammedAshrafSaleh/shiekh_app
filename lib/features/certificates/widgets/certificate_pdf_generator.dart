// lib/features/certificates/widgets/certificate_pdf_generator.dart
//
// Vector PDF certificate. Fonts: Aref Ruqaa (headings) + Tajawal (body).
// Colors match design_tokens.json. Double border + corner ornaments to match
// the Flutter-side CertificateBorder CustomPainter.
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../models/certificate_entity.dart';

// Design-token colours as PDF constants.
const _pPrimary = PdfColor.fromInt(0xFF1E4034);
const _pGold = PdfColor.fromInt(0xFFC09A4E);
const _pPaper = PdfColor.fromInt(0xFFFBF7EF);
const _pInk = PdfColor.fromInt(0xFF3B2E23);
const _pInkMuted = PdfColor.fromInt(0xFF6B5B4B);
const _pInkFaint = PdfColor.fromInt(0xFFA2937F);

class CertificatePdfGenerator {
  static Future<List<int>> generate({
    required CertificateEntity certificate,
    required String studentName,
    required String bookTitle,
    required String sheikhName,
  }) async {
    // Load design-system fonts.
    // NOTE: the `pdf` package's Arabic shaper cannot render the display/heading
    // faces used in-app — Aref Ruqaa (headings) and Reem Kufi (footer values)
    // both rely on mandatory ligatures/contextual forms the shaper drops,
    // producing disconnected/tofu glyphs. Only Tajawal (body) and Amiri shape
    // correctly through it. So the PDF export substitutes:
    //   headings   -> Amiri Bold      (closest classical calligraphic match)
    //   footer vals -> Tajawal Bold   (Reem Kufi can't shape "ممتاز" / lacks ٪)
    // The in-app preview still uses the design-system Aref Ruqaa / Reem Kufi,
    // which Flutter shapes natively. Verified via tool render (see git history).
    final headingBold = await PdfGoogleFonts.amiriBold();
    final tajawalRegular = await PdfGoogleFonts.tajawalRegular();
    final tajawalMedium = await PdfGoogleFonts.tajawalMedium();
    final tajawalBold = await PdfGoogleFonts.tajawalBold();

    final theme = pw.ThemeData.withFont(
      base: tajawalRegular,
      bold: tajawalBold,
    );

    final grade =
        '${certificate.finalScore}٪${certificate.gradeLabel != null ? ' (${certificate.gradeLabel})' : ''}';
    final issuedDate = DateFormat(
      'yyyy/M/d',
      'ar',
    ).format(certificate.issuedAt);

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) {
          return pw.Stack(
            children: [
              // 1. Paper background
              pw.Positioned.fill(child: pw.Container(color: _pPaper)),

              // 2. Outer primary border
              pw.Positioned.fill(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _pPrimary, width: 3),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                ),
              ),

              // 3. Inner gold hairline border
              pw.Positioned(
                left: 12,
                right: 12,
                top: 12,
                bottom: 12,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _pGold, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                ),
              ),

              // 4. Corner ornaments
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  painter: (canvas, size) => _paintCorners(canvas, size),
                ),
              ),

              // 5. Certificate content (centred)
              pw.Positioned.fill(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 24,
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Bismillah
                      pw.Text(
                        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                        style: pw.TextStyle(
                          font: tajawalMedium,
                          fontSize: 11,
                          color: _pGold,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 3),
                      _goldLine(width: 50),
                      pw.SizedBox(height: 10),

                      // Title
                      pw.Text(
                        'شهادة إتمام',
                        style: pw.TextStyle(
                          font: headingBold,
                          fontSize: 34,
                          color: _pPrimary,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      _ornamentSeparator(),
                      pw.SizedBox(height: 12),

                      // Attestation line
                      pw.Text(
                        'تشهد إدارة الأكاديمية بأنَّ الطالب/ة',
                        style: pw.TextStyle(
                          font: tajawalRegular,
                          fontSize: 12,
                          color: _pInkMuted,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),

                      // Student name
                      pw.Text(
                        studentName,
                        style: pw.TextStyle(
                          font: headingBold,
                          fontSize: 26,
                          color: _pPrimary,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      _goldLine(width: 160),
                      pw.SizedBox(height: 12),

                      // Body text
                      pw.Text(
                        'قد أتمّ/ت بعون الله وتوفيقه دراسة $bookTitle',
                        style: pw.TextStyle(
                          font: tajawalRegular,
                          fontSize: 12,
                          color: _pInk,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'بإشراف فضيلة الشيخ $sheikhName',
                        style: pw.TextStyle(
                          font: tajawalRegular,
                          fontSize: 12,
                          color: _pInk,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 18),

                      // Footer: التقدير / التاريخ centered together under the
                      // last line
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _footerColumn(
                            label: 'التقدير',
                            value: grade,
                            labelFont: tajawalRegular,
                            valueFont: tajawalBold,
                          ),
                          pw.SizedBox(width: 40),
                          _footerColumn(
                            label: 'التاريخ',
                            value: issuedDate,
                            labelFont: tajawalRegular,
                            valueFont: tajawalBold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _goldLine({double width = double.infinity}) =>
      pw.Container(width: width, height: 0.8, color: _pGold);

  // Ornament separator: gold hairline with a center diamond.
  static pw.Widget _ornamentSeparator() {
    return pw.CustomPaint(
      size: const PdfPoint(200, 14),
      painter: (PdfGraphics canvas, PdfPoint size) {
        const diamondHalf = 4.5;
        final midX = size.x / 2;
        final midY = size.y / 2;

        canvas
          ..setStrokeColor(_pGold)
          ..setLineWidth(0.8);

        // Left arm
        canvas
          ..moveTo(0, midY)
          ..lineTo(midX - diamondHalf - 5, midY)
          ..strokePath();

        // Right arm
        canvas
          ..moveTo(midX + diamondHalf + 5, midY)
          ..lineTo(size.x, midY)
          ..strokePath();

        // Diamond fill
        canvas
          ..setFillColor(_pGold)
          ..moveTo(midX, midY - diamondHalf)
          ..lineTo(midX + diamondHalf, midY)
          ..lineTo(midX, midY + diamondHalf)
          ..lineTo(midX - diamondHalf, midY)
          ..closePath()
          ..fillPath();
      },
    );
  }

  static pw.Widget _footerColumn({
    required String label,
    required String value,
    required pw.Font labelFont,
    required pw.Font valueFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: labelFont, fontSize: 10, color: _pInkFaint),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(font: valueFont, fontSize: 12, color: _pInk),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 3),
        pw.Container(width: 90, height: 0.8, color: _pGold),
      ],
    );
  }

  // Corner ornaments: L-brackets (gold) + filled diamond at each inner-border corner.
  static void _paintCorners(PdfGraphics canvas, PdfPoint size) {
    const inset = 12.0;
    const cornerLen = 26.0;
    const diamondHalf = 4.0;

    canvas
      ..setStrokeColor(_pGold)
      ..setLineWidth(1.5);

    // PDF y=0 is bottom-left, y=size.y is top-left.
    for (final (cx, cy, sx, sy) in [
      (inset, inset, 1.0, 1.0), // bottom-left
      (size.x - inset, inset, -1.0, 1.0), // bottom-right
      (inset, size.y - inset, 1.0, -1.0), // top-left
      (size.x - inset, size.y - inset, -1.0, -1.0), // top-right
    ]) {
      // Horizontal arm
      canvas
        ..moveTo(cx, cy)
        ..lineTo(cx + sx * cornerLen, cy)
        ..strokePath();

      // Vertical arm
      canvas
        ..moveTo(cx, cy)
        ..lineTo(cx, cy + sy * cornerLen)
        ..strokePath();

      // Diamond
      canvas
        ..setFillColor(_pGold)
        ..moveTo(cx, cy - sy * diamondHalf)
        ..lineTo(cx + sx * diamondHalf, cy)
        ..lineTo(cx, cy + sy * diamondHalf)
        ..lineTo(cx - sx * diamondHalf, cy)
        ..closePath()
        ..fillPath();
    }
  }
}
