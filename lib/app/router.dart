// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/auth/view/forgot_password_page.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/reset_sent_page.dart';
import '../features/auth/view/signup_page.dart';
import '../features/auth/view/splash_page.dart';

// --- Placeholder pages (replaced phase by phase) ---
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}

// --------------- Router factory ---------------

GoRouter buildRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthNotifier(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      final loc = state.matchedLocation;

      final isOnSplash = loc == '/splash';
      final isOnAuth = loc.startsWith('/login') ||
          loc.startsWith('/signup') ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/reset-sent') ||
          loc.startsWith('/reset-callback');

      // Transient states — don't redirect; let BlocListeners in the pages drive navigation
      if (authState is AuthPasswordResetSent || authState is AuthEmailConfirmationRequired) {
        return null;
      }

      if (authState is AuthInitial || authState is AuthLoading) {
        return isOnSplash ? null : '/splash';
      }

      if (authState is AuthError) {
        // Stay on auth screens; the BlocListener in each page shows the error
        return isOnAuth ? null : '/login';
      }

      if (authState is AuthUnauthenticated) {
        return isOnAuth ? null : '/login';
      }

      if (authState is AuthAuthenticated) {
        if (isOnAuth || isOnSplash) {
          return authState.isAdmin ? '/admin' : '/home';
        }
        if (loc.startsWith('/admin') && !authState.isAdmin) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignupPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-sent',
        builder: (_, state) {
          final email = state.extra as String? ?? '';
          return ResetSentPage(email: email);
        },
      ),
      // Deep link callback from Supabase password-reset email
      // Supabase Flutter SDK automatically picks up the session from the URL fragment;
      // authStateChanges fires and the redirect above routes the user correctly.
      GoRoute(
        path: '/reset-callback',
        builder: (_, _) => const SplashPage(),
      ),

      // --- Student Shell ---
      ShellRoute(
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const _PlaceholderPage('الرئيسية'),
          ),
          GoRoute(
            path: '/path',
            builder: (_, _) => const _PlaceholderPage('مساري'),
          ),
          GoRoute(
            path: '/achievements',
            builder: (_, _) => const _PlaceholderPage('إنجازاتي'),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const _PlaceholderPage('حسابي'),
          ),
        ],
      ),

      // --- Admin Shell ---
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => const _PlaceholderPage('لوحة التحكم'),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, _) => const _PlaceholderPage('الإعدادات'),
          ),
        ],
      ),
    ],
  );
}

// --------------- Shell widgets (placeholder nav) ---------------

class _StudentShell extends StatelessWidget {
  final Widget child;
  const _StudentShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: 'مساري'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'إنجازاتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
        onDestinationSelected: (i) {
          const routes = ['/home', '/path', '/achievements', '/profile'];
          context.go(routes[i]);
        },
      ),
    );
  }
}

class _AdminShell extends StatelessWidget {
  final Widget child;
  const _AdminShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'لوحة التحكم'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
        ],
        onDestinationSelected: (i) {
          const routes = ['/admin', '/admin/settings'];
          context.go(routes[i]);
        },
      ),
    );
  }
}

// --------------- Listenable bridge ---------------

class _AuthNotifier extends ChangeNotifier {
  final AuthCubit _cubit;

  _AuthNotifier(this._cubit) {
    _cubit.stream.listen((_) => notifyListeners());
  }
}
