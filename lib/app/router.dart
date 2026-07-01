// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';

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
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (authState is AuthInitial || authState is AuthLoading) {
        return isOnSplash ? null : '/splash';
      }

      if (authState is AuthUnauthenticated) {
        return isOnAuth ? null : '/login';
      }

      if (authState is AuthAuthenticated) {
        if (isOnAuth || isOnSplash) {
          return authState.isAdmin ? '/admin' : '/home';
        }
        if (state.matchedLocation.startsWith('/admin') && !authState.isAdmin) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (ctx, _) => const _PlaceholderPage('Splash'),
      ),
      GoRoute(
        path: '/login',
        builder: (ctx, _) => const _PlaceholderPage('تسجيل الدخول'),
      ),
      GoRoute(
        path: '/signup',
        builder: (ctx, _) => const _PlaceholderPage('إنشاء حساب'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (ctx, _) => const _PlaceholderPage('نسيت كلمة المرور'),
      ),

      // --- Student Shell ---
      ShellRoute(
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, _) => const _PlaceholderPage('الرئيسية'),
          ),
          GoRoute(
            path: '/path',
            builder: (ctx, _) => const _PlaceholderPage('مساري'),
          ),
          GoRoute(
            path: '/achievements',
            builder: (ctx, _) => const _PlaceholderPage('إنجازاتي'),
          ),
          GoRoute(
            path: '/profile',
            builder: (ctx, _) => const _PlaceholderPage('حسابي'),
          ),
        ],
      ),

      // --- Admin Shell ---
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (ctx, _) => const _PlaceholderPage('لوحة التحكم'),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (ctx, _) => const _PlaceholderPage('الإعدادات'),
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
