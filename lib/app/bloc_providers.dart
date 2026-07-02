// lib/app/bloc_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/theme_cubit.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/notifications/cubit/connectivity_cubit.dart';
import '../features/path/data/path_repository.dart';
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
