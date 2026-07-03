// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/achievements/cubit/achievements_cubit.dart';
import '../features/achievements/data/achievements_repository.dart';
import '../features/achievements/view/achievements_page.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/auth/view/forgot_password_page.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/reset_sent_page.dart';
import '../features/auth/view/signup_page.dart';
import '../features/auth/view/splash_page.dart';
import '../features/books/cubit/book_details_cubit.dart';
import '../features/books/data/book_repository.dart';
import '../features/books/view/book_details_page.dart';
import '../features/certificates/view/certificate_detail_page.dart';
import '../features/exam/bloc/exam_bloc.dart';
import '../features/exam/bloc/exam_event.dart';
import '../features/exam/bloc/exam_state.dart';
import '../features/exam/data/exam_repository.dart';
import '../features/exam/view/exam_page.dart';
import '../features/exam/view/exam_result_page.dart';
import '../features/home/cubit/home_cubit.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/view/home_page.dart';
import '../features/lesson/cubit/lesson_cubit.dart';
import '../features/lesson/data/lesson_repository.dart';
import '../features/lesson/view/lesson_page.dart';
import '../features/path/cubit/path_cubit.dart';
import '../features/path/data/path_repository.dart';
import '../features/path/view/path_page.dart';
import '../features/qa/cubit/qa_cubit.dart';
import '../features/qa/data/qa_repository.dart';
import '../features/qa/view/book_qa_page.dart';
import '../features/sections/cubit/section_books_cubit.dart';
import '../features/sections/cubit/sections_cubit.dart';
import '../features/sections/data/section_repository.dart';
import '../features/sections/view/section_books_page.dart';
import '../features/sections/view/sections_page.dart';
import '../models/certificate_entity.dart';

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

      if (authState is AuthPasswordResetSent ||
          authState is AuthEmailConfirmationRequired) {
        return null;
      }

      if (authState is AuthInitial || authState is AuthLoading) {
        if (isOnSplash || isOnAuth) return null;
        return '/splash';
      }

      if (authState is AuthError) {
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
            builder: (context, _) => BlocProvider(
              create: (ctx) =>
                  HomeCubit(ctx.read<HomeRepository>())..loadHome(),
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: '/path',
            builder: (context, _) => BlocProvider(
              create: (ctx) =>
                  PathCubit(ctx.read<PathRepository>())..loadPath(),
              child: const PathPage(),
            ),
          ),
          GoRoute(
            path: '/achievements',
            builder: (context, _) => BlocProvider(
              create: (ctx) => AchievementsCubit(
                  ctx.read<AchievementsRepository>()),
              child: const AchievementsPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const _PlaceholderPage('حسابي'),
          ),
        ],
      ),

      // --- Full-page routes (not in shell) ---
      GoRoute(
        path: '/sections',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              SectionsCubit(ctx.read<SectionRepository>())..loadSections(),
          child: const SectionsPage(),
        ),
      ),
      GoRoute(
        path: '/sections/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (ctx) =>
                SectionBooksCubit(ctx.read<SectionRepository>())
                  ..loadBooks(id),
            child: SectionBooksPage(sectionId: id),
          );
        },
      ),

      // --- Book Details (Task 3.1 / 3.2) ---
      GoRoute(
        path: '/books/:id',
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return BlocProvider(
            create: (ctx) => BookDetailsCubit(ctx.read<BookRepository>()),
            child: BookDetailsPage(bookId: bookId),
          );
        },
        routes: [
          // Book-level Q&A (Task 3.10)
          GoRoute(
            path: 'qa',
            builder: (context, state) {
              final bookId = state.pathParameters['id']!;
              return BlocProvider(
                create: (ctx) => QaCubit(ctx.read<QaRepository>()),
                child: BookQaPage(bookId: bookId),
              );
            },
          ),
          // Exam routes (Phase 4)
          GoRoute(
            path: 'exam',
            builder: (context, routeState) {
              final bookId = routeState.pathParameters['id']!;
              // bookTitle passed via extra or falls back
              final extra = routeState.extra;
              final bookTitle =
                  extra is String ? extra : 'الاختبار الشامل';
              return BlocProvider(
                create: (ctx) => ExamBloc(ctx.read<ExamRepository>())
                  ..add(ExamLoadRequested(bookId)),
                child: ExamPage(
                  bookId: bookId,
                  bookTitle: bookTitle,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, routeState) {
                  final examCompleted =
                      routeState.extra as ExamCompleted;
                  return ExamResultPage(examCompleted: examCompleted);
                },
              ),
            ],
          ),
        ],
      ),

      // --- Certificate Detail (Task 4.6) ---
      GoRoute(
        path: '/certificates/:bookId',
        builder: (context, state) {
          final extra = state.extra;
          final cert = extra is CertificateEntity ? extra : null;
          final bookId = state.pathParameters['bookId']!;
          if (cert == null) {
            return const _PlaceholderPage('الشهادة');
          }
          return CertificateDetailPage(
            certificate: cert,
            bookTitle: bookId,
            studentName: '',
          );
        },
      ),

      // --- Lesson (Tasks 3.3–3.8) ---
      GoRoute(
        path: '/lessons/:id',
        builder: (context, state) {
          final lessonId = state.pathParameters['id']!;
          final bookId = state.uri.queryParameters['bookId'] ?? '';
          return BlocProvider(
            create: (ctx) => LessonCubit(ctx.read<LessonRepository>()),
            child: LessonPage(lessonId: lessonId, bookId: bookId),
          );
        },
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

// --------------- Shell widgets ---------------

class _StudentShell extends StatelessWidget {
  final Widget child;
  const _StudentShell({required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/path')) return 1;
    if (loc.startsWith('/achievements')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'مساري',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'إنجازاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
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
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'لوحة التحكم',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
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
