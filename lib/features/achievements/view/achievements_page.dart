// lib/features/achievements/view/achievements_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
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
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheikhyPageHeader(title: 'إنجازاتي'),
          const Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AchievementsCubit, AchievementsState>(
      builder: (context, state) {
        return switch (state) {
          AchievementsInitial() || AchievementsLoading() => const _LoadingView(),
          AchievementsError(:final message) => SheikhyErrorState(
              heading: 'تعذّر تحميل الإنجازات',
              message: message,
              onRetry: () =>
                  context.read<AchievementsCubit>().loadAchievements(),
            ),
          AchievementsLoaded() => _LoadedView(state: state),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('جار تحميل المحتوى...', style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final AchievementsLoaded state;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => context.read<AchievementsCubit>().loadAchievements(),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.pageGutter,
          AppSpacing.s4,
          AppSpacing.pageGutter,
          AppSpacing.s7,
        ),
        children: [
          _StatRow(data: state.data),
          const SizedBox(height: AppSpacing.s5),
          _HeatmapSection(activityByDate: state.data.activityByDate),
          const SizedBox(height: AppSpacing.s5),
          _CertificatesSection(
            certificates: state.certificates,
            onDownload: (cert) => _downloadCertificate(context, cert),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCertificate(
    BuildContext context,
    CertificateEntity cert,
  ) async {
    final authState = context.read<AuthCubit>().state;
    String studentName = '';
    if (authState is AuthAuthenticated) {
      final meta = authState.user.userMetadata;
      studentName =
          (meta != null ? meta['full_name'] as String? : null) ?? '';
    }
    final bookTitle = cert.bookTitle?.trim() ?? '';
    try {
      final bytes = await CertificatePdfGenerator.generate(
        certificate: cert,
        studentName: studentName,
        bookTitle: bookTitle,
        sheikhName: AppConfig.sheikhName,
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: bookTitle.isEmpty ? 'شهادة.pdf' : 'شهادة $bookTitle.pdf',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ أثناء توليد الشهادة'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

// ── Stat row ──────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({required this.data});

  final dynamic data; // AchievementsData

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // RTL order (right → left): hours | certificates | completed
        Expanded(
          child: StatCard(
            icon: Icons.schedule_outlined,
            value: data.estimatedStudyHours as int,
            label: 'ساعة دراسة',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: StatCard(
            icon: Icons.emoji_events_outlined,
            value: data.certificateCount as int,
            label: 'شهادة',
            color: AppColors.goldDeep,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: StatCard(
            icon: Icons.check_circle_outline,
            value: data.completedLessons as int,
            label: 'درس مكتمل',
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// ── Heatmap section ───────────────────────────────────────────────────────────

class _HeatmapSection extends StatelessWidget {
  const _HeatmapSection({required this.activityByDate});

  final Map<DateTime, int> activityByDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('النشاط الدراسي', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.s3),
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
          child: activityByDate.isNotEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // 7 cells × 4 px margin each; derive cell size to fit exactly
                    final cellSize = (constraints.maxWidth - 28) / 7;
                    return HeatMapCalendar(
                      datasets: activityByDate,
                      size: cellSize,
                      colorsets: {
                        1: AppColors.primary.withValues(alpha: 0.25),
                        2: AppColors.primary.withValues(alpha: 0.50),
                        3: AppColors.primary.withValues(alpha: 0.75),
                        4: AppColors.primary,
                      },
                      textColor: AppColors.inkMuted,
                      defaultColor: AppColors.paperSunk,
                      showColorTip: false,
                    );
                  },
                )
              : Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.s5,
                  ),
                  child: Center(
                    child: Text(
                      'ابدأ الدراسة لترى نشاطك هنا',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Certificates section ──────────────────────────────────────────────────────

class _CertificatesSection extends StatelessWidget {
  const _CertificatesSection({
    required this.certificates,
    required this.onDownload,
  });

  final List<CertificateEntity> certificates;
  final void Function(CertificateEntity) onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('شهاداتي', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.s3),
        if (certificates.isEmpty)
          const SheikhyEmptyState(
            icon: Icons.emoji_events_outlined,
            heading: 'لا توجد شهادات بعد',
            subtitle: 'أكمل اختباراً شاملاً للحصول على شهادة.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: certificates.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
            itemBuilder: (context, index) {
              final cert = certificates[index];
              return CertificateCard(
                certificate: cert,
                bookTitle: cert.bookTitle,
                onDownload: () => onDownload(cert),
              );
            },
          ),
      ],
    );
  }
}
