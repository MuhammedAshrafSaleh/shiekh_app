// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/notifications/cubit_notifs/notifications_cubit.dart';
import 'router.dart';

class SheikhyApp extends StatefulWidget {
  const SheikhyApp({super.key});

  @override
  State<SheikhyApp> createState() => _SheikhyAppState();
}

class _SheikhyAppState extends State<SheikhyApp> {
  late final GoRouterWrapper _routerWrapper;

  @override
  void initState() {
    super.initState();
    _routerWrapper = GoRouterWrapper(context.read<AuthCubit>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      // Preload notifications so the home badge reflects the unread count
      // as soon as a student signs in (or the session is restored).
      listenWhen: (prev, curr) =>
          curr is AuthAuthenticated &&
          !curr.isAdmin &&
          prev is! AuthAuthenticated,
      listener: (context, state) =>
          context.read<NotificationsCubit>().loadNotifications(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'شيخي',
            debugShowCheckedModeBanner: false,
            // RTL + Arabic locale
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Theme
            theme: AppTheme.light(primaryColor: AppConfig.primaryColor),
            darkTheme: AppTheme.dark(primaryColor: AppConfig.primaryColor),
            themeMode: themeMode,
            // Router
            routerConfig: _routerWrapper.router,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _routerWrapper.dispose();
    super.dispose();
  }
}

class GoRouterWrapper {
  final AuthCubit _authCubit;
  late final router = buildRouter(_authCubit);

  GoRouterWrapper(this._authCubit);

  void dispose() => router.dispose();
}
