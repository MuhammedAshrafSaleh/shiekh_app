// lib/features/certificates/widgets/certificate_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/certificate_entity.dart';

class CertificateCard extends StatelessWidget {
  const CertificateCard({
    super.key,
    required this.certificate,
    this.bookTitle,
    this.onDownload,
  });

  final CertificateEntity certificate;

  /// The human-readable book name. When null/empty 'شهادة إتمام' is shown.
  final String? bookTitle;
  final VoidCallback? onDownload;

  String get _title {
    final name = bookTitle?.trim();
    if (name == null || name.isEmpty) return 'شهادة إتمام';
    return 'شهادة إتمام — $name';
  }

  String get _dateLabel {
    final hd = DateFormat('yyyy/M/d', 'ar').format(certificate.issuedAt);
    return 'صدرت في $hd';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // start (right in RTL): decorative gold book icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: AppRadii.rMd,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: AppColors.goldDeep,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),

            // content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: GoogleFonts.arefRuqaa(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    certificate.gradeLabel != null
                        ? '$_dateLabel · بتقدير ${certificate.gradeLabel}'
                        : _dateLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.inkMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),

            // end (left in RTL): download action
            if (onDownload != null) ...[
              const SizedBox(width: AppSpacing.s3),
              GestureDetector(
                onTap: onDownload,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadii.rMd,
                  ),
                  child: const Icon(
                    Icons.download_outlined,
                    color: AppColors.inkInvert,
                    size: 22,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
