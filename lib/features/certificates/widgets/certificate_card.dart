// lib/features/certificates/widgets/certificate_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/certificate_entity.dart';

class CertificateCard extends StatelessWidget {
  final CertificateEntity certificate;
  final String? bookTitle;
  final VoidCallback? onDownload;

  const CertificateCard({
    super.key,
    required this.certificate,
    this.bookTitle,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    const gold = Color(0xFFD4A017);

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: Container(
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: gold, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1FD4A017),
                ),
                child: const Icon(Icons.emoji_events, color: gold, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookTitle != null)
                      Text(
                        bookTitle!,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${certificate.finalScore}٪',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (certificate.gradeLabel != null) ...[
                          Text(
                            '  •  ${certificate.gradeLabel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(certificate.issuedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDownload != null)
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: onDownload,
                  tooltip: 'تحميل الشهادة',
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
