// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_messenger.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart' show AppTheme;
import '../core/theme/theme_cubit.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/auth/pending_conversion.dart';
import '../features/auth/post_auth_flow.dart';
import '../features/books/data/book_repository.dart';
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
            // Theme-aware overlay style for screens without an AppBar. Screens
            // that have an AppBar are covered by AppBarTheme.systemOverlayStyle
            // (an AppBar overrides an AnnotatedRegion placed above it).
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.overlayStyle(
                  isDark ? Brightness.dark : Brightness.light,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
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
