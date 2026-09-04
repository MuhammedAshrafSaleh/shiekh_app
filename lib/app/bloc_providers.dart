// lib/app/bloc_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/theme_cubit.dart';
import '../features/achievements/data/achievements_repository.dart';
import '../features/admin/banners/data/admin_banner_repository.dart';
import '../features/admin/books/data/admin_book_repository.dart';
import '../features/admin/dashboard/data/admin_dashboard_repository.dart';
import '../features/admin/exam/data/admin_exam_repository.dart';
import '../features/admin/lessons/data/admin_lesson_repository.dart';
import '../features/admin/notifications/data/admin_notifications_repository.dart';
import '../features/admin/onboarding/data/admin_onboarding_repository.dart';
import '../features/admin/qa/data/admin_qa_repository.dart';
import '../features/admin/sections/data/admin_section_repository.dart';
import '../features/admin/stats/data/admin_stats_repository.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/books/data/book_repository.dart';
import '../features/certificates/data/certificate_repository.dart';
import '../features/exam/data/exam_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/lesson/data/lesson_repository.dart';
import '../features/lesson/data/video_stream_repository.dart';
import '../features/notifications/cubit/connectivity_cubit.dart';
import '../features/notifications/cubit_notifs/notifications_cubit.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/qa/data/qa_repository.dart';
import '../features/sections/data/section_repository.dart';
import 'app.dart';

class SheikhyProviders extends StatelessWidget {
  const SheikhyProviders({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()..load()),
        BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()),
      ],
      child: Builder(
        builder: (ctx) {
          final connectivity = ctx.read<ConnectivityCubit>();
          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AuthRepository>(
                create: (_) => AuthRepository(supabase),
              ),
              RepositoryProvider<HomeRepository>(
                create: (_) => HomeRepository(supabase, connectivity),
              ),
              RepositoryProvider<SectionRepository>(
                create: (_) => SectionRepository(supabase, connectivity),
              ),
              RepositoryProvider<OnboardingRepository>(
                create: (_) => OnboardingRepository(supabase, connectivity),
              ),
              RepositoryProvider<BookRepository>(
                create: (_) => BookRepository(supabase, connectivity),
              ),
              RepositoryProvider<LessonRepository>(
                create: (_) => LessonRepository(supabase, connectivity),
              ),
              RepositoryProvider<VideoStreamRepository>(
                create: (_) => VideoStreamRepository(),
              ),
              RepositoryProvider<QaRepository>(
                create: (_) => QaRepository(supabase, connectivity),
              ),
              RepositoryProvider<ExamRepository>(
                create: (_) => ExamRepository(supabase, connectivity),
              ),
              RepositoryProvider<CertificateRepository>(
                create: (_) => CertificateRepository(supabase, connectivity),
              ),
              RepositoryProvider<AchievementsRepository>(
                create: (_) => AchievementsRepository(supabase, connectivity),
              ),
              RepositoryProvider<ProfileRepository>(
                create: (_) => ProfileRepository(supabase, connectivity),
              ),
              RepositoryProvider<NotificationsRepository>(
                create: (_) => NotificationsRepository(supabase, connectivity),
              ),
              // --- Admin repositories (Phase 6) ---
              RepositoryProvider<AdminDashboardRepository>(
                create: (_) => AdminDashboardRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminSectionRepository>(
                create: (_) => AdminSectionRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminBookRepository>(
                create: (_) => AdminBookRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminBannerRepository>(
                create: (_) => AdminBannerRepository(supabase, connectivity),
              ),
              // --- Admin repositories (Phase 7) ---
              RepositoryProvider<AdminLessonRepository>(
                create: (_) => AdminLessonRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminExamRepository>(
                create: (_) => AdminExamRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminStatsRepository>(
                create: (_) => AdminStatsRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminQaRepository>(
                create: (_) => AdminQaRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminNotificationsRepository>(
                create: (_) =>
                    AdminNotificationsRepository(supabase, connectivity),
              ),
              RepositoryProvider<AdminOnboardingRepository>(
                create: (_) =>
                    AdminOnboardingRepository(supabase, connectivity),
              ),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>(
                  create: (repoCtx) =>
                      AuthCubit(repoCtx.read<AuthRepository>())..initialize(),
                ),
                BlocProvider<NotificationsCubit>(
                  create: (repoCtx) => NotificationsCubit(
                    repoCtx.read<NotificationsRepository>(),
                  ),
                ),
              ],
              child: const SheikhyApp(),
            ),
          );
        },
      ),
    );
  }
}
