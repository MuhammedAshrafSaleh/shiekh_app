// lib/app/bloc_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/theme_cubit.dart';
import '../features/achievements/data/achievements_repository.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/books/data/book_repository.dart';
import '../features/certificates/data/certificate_repository.dart';
import '../features/exam/data/exam_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/lesson/data/lesson_repository.dart';
import '../features/notifications/cubit/connectivity_cubit.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/path/data/path_repository.dart';
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
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit()..load(),
        ),
        BlocProvider<ConnectivityCubit>(
          create: (_) => ConnectivityCubit(),
        ),
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
              RepositoryProvider<PathRepository>(
                create: (_) => PathRepository(supabase, connectivity),
              ),
              RepositoryProvider<SectionRepository>(
                create: (_) => SectionRepository(supabase, connectivity),
              ),
              RepositoryProvider<BookRepository>(
                create: (_) => BookRepository(supabase, connectivity),
              ),
              RepositoryProvider<LessonRepository>(
                create: (_) => LessonRepository(supabase, connectivity),
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
                create: (_) =>
                    AchievementsRepository(supabase, connectivity),
              ),
              RepositoryProvider<ProfileRepository>(
                create: (_) => ProfileRepository(supabase, connectivity),
              ),
              RepositoryProvider<NotificationsRepository>(
                create: (_) =>
                    NotificationsRepository(supabase, connectivity),
              ),
            ],
            child: BlocProvider<AuthCubit>(
              create: (repoCtx) =>
                  AuthCubit(repoCtx.read<AuthRepository>())..initialize(),
              child: const SheikhyApp(),
            ),
          );
        },
      ),
    );
  }
}
