// lib/features/achievements/view/achievements_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../features/auth/cubit/auth_state.dart';
import '../../../features/certificates/widgets/certificate_card.dart';
import '../../../features/certificates/widgets/certificate_pdf_generator.dart';
import '../../../models/certificate_entity.dart';
import '../cubit/achievements_cubit.dart';
import '../cubit/achievements_state.dart';
import '../widgets/stat_card.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AchievementsCubit>().loadAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنجازاتي'),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<AchievementsCubit, AchievementsState>(
        builder: (context, state) {
          return switch (state) {
            AchievementsInitial() || AchievementsLoading() =>
              const Center(child: CircularProgressIndicator()),
            AchievementsError(:final message) => ErrorState(
                message: message,
                onRetry: () =>
                    context.read<AchievementsCubit>().loadAchievements(),
              ),
            AchievementsLoaded() => _AchievementsView(
                state: state,
              ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _AchievementsView extends StatelessWidget {
  final AchievementsLoaded state;

  const _AchievementsView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const gold = Color(0xFFD4A017);

    return RefreshIndicator(
      onRefresh: () => context.read<AchievementsCubit>().loadAchievements(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 3 stat cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.check_circle_outline,
                  value: '${state.data.completedLessons}',
                  label: 'درس مكتمل',
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  icon: Icons.emoji_events_outlined,
                  value: '${state.data.certificateCount}',
                  label: 'شهادة',
                  color: gold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  icon: Icons.schedule_outlined,
                  value: '${state.data.estimatedStudyHours}',
                  label: 'ساعة دراسة',
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Activity Heatmap (plan M)
          Text(
            'النشاط الدراسي',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.data.activityByDate.isNotEmpty)
            HeatMapCalendar(
              datasets: state.data.activityByDate,
              colorsets: {
                1: colorScheme.primary.withValues(alpha: 0.25),
                2: colorScheme.primary.withValues(alpha: 0.5),
                3: colorScheme.primary.withValues(alpha: 0.75),
                4: colorScheme.primary,
              },
              colorTipHelper: const [
                Text('أقل', style: TextStyle(fontSize: 10)),
                null,
                null,
                Text('أكثر', style: TextStyle(fontSize: 10)),
              ],
              textColor: colorScheme.onSurface,
              defaultColor:
                  colorScheme.surfaceContainerHighest,
              showColorTip: true,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'ابدأ الدراسة لترى نشاطك هنا',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Certificates list
          Text(
            'شهاداتي',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.certificates.isEmpty)
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              message: 'لا توجد شهادات بعد\nأكمل اختباراً شاملاً للحصول على شهادة',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.certificates.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final cert = state.certificates[index];
                return CertificateCard(
                  certificate: cert,
                  bookTitle: cert.bookId, // replaced in detail page with real title
                  onDownload: () =>
                      _downloadCertificate(context, cert),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _downloadCertificate(
      BuildContext context, CertificateEntity cert) async {
    final authState = context.read<AuthCubit>().state;
    String studentName = '';
    if (authState is AuthAuthenticated) {
      final meta = authState.user.userMetadata;
      studentName = (meta != null ? meta['full_name'] as String? : null) ?? '';
    }

    try {
      final bytes = await CertificatePdfGenerator.generate(
        certificate: cert,
        studentName: studentName,
        bookTitle: cert.bookId,
        sheikhName: AppConfig.sheikhName,
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'شهادة.pdf',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء توليد الشهادة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
