// lib/app/bloc_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/theme_cubit.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/notifications/cubit/connectivity_cubit.dart';
import 'app.dart';

class SheikhyProviders extends StatelessWidget {
  const SheikhyProviders({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(supabase),
        ),
        // Feature repositories are added here as phases are completed
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(
            create: (_) => ThemeCubit()..load(),
          ),
          BlocProvider<ConnectivityCubit>(
            create: (_) => ConnectivityCubit(),
          ),
          BlocProvider<AuthCubit>(
            create: (ctx) => AuthCubit(ctx.read<AuthRepository>())
              ..initialize(),
          ),
        ],
        child: const SheikhyApp(),
      ),
    );
  }
}
