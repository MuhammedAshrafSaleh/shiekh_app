// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/offline_banner.dart';
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
import '../features/lesson/data/video_stream_repository.dart';
import '../features/lesson/view/lesson_page.dart';
import '../features/notifications/view/notifications_page.dart';
import '../features/profile/cubit/profile_cubit.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/view/change_password_page.dart';
import '../features/profile/view/edit_profile_page.dart';
import '../features/profile/view/profile_page.dart';
import '../features/qa/cubit/my_questions_cubit.dart';
import '../features/qa/cubit/qa_cubit.dart';
import '../features/qa/data/qa_repository.dart';
import '../features/qa/view/book_qa_page.dart';
import '../features/qa/view/my_questions_page.dart';
import '../features/sections/cubit/section_books_cubit.dart';
import '../features/sections/cubit/sections_cubit.dart';
import '../features/sections/data/section_repository.dart';
import '../features/sections/view/section_books_page.dart';
import '../features/sections/view/sections_page.dart';
import '../features/admin/dashboard/cubit/admin_dashboard_cubit.dart';
import '../features/admin/dashboard/data/admin_dashboard_repository.dart';
import '../features/admin/dashboard/view/admin_dashboard_page.dart';
import '../features/admin/sections/cubit/admin_sections_cubit.dart';
import '../features/admin/sections/data/admin_section_repository.dart';
import '../features/admin/sections/view/admin_section_form_page.dart';
import '../features/admin/sections/view/admin_sections_page.dart';
import '../features/admin/books/cubit/admin_book_cubit.dart';
import '../features/admin/books/data/admin_book_repository.dart';
import '../features/admin/books/view/admin_book_form_page.dart';
import '../features/admin/banners/cubit/admin_banner_cubit.dart';
import '../features/admin/banners/data/admin_banner_repository.dart';
import '../features/admin/banners/view/admin_banner_form_page.dart';
import '../features/admin/banners/view/admin_banners_page.dart';
import '../features/admin/exam/cubit/admin_exam_cubit.dart';
import '../features/admin/exam/data/admin_exam_repository.dart';
import '../features/admin/exam/view/admin_exam_page.dart';
import '../features/admin/lessons/cubit/admin_lesson_cubit.dart';
import '../features/admin/lessons/data/admin_lesson_repository.dart';
import '../features/admin/lessons/view/admin_lesson_form_page.dart';
import '../features/admin/lessons/view/admin_lessons_page.dart';
import '../features/admin/notifications/cubit/admin_notifications_cubit.dart';
import '../features/admin/notifications/data/admin_notifications_repository.dart';
import '../features/admin/notifications/view/admin_notification_form_page.dart';
import '../features/admin/notifications/view/admin_notifications_page.dart';
import '../features/admin/qa/cubit/admin_qa_cubit.dart';
import '../features/admin/qa/data/admin_qa_repository.dart';
import '../features/admin/qa/view/admin_qa_page.dart';
import '../features/admin/settings/view/admin_settings_page.dart';
import '../features/admin/stats/cubit/admin_stats_cubit.dart';
import '../features/admin/stats/data/admin_stats_repository.dart';
import '../features/admin/stats/view/admin_book_dashboard_page.dart';
import '../models/banner_entity.dart';
import '../models/book_entity.dart';
import '../models/certificate_entity.dart';
import '../models/section_entity.dart';

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
                  SectionsCubit(ctx.read<SectionRepository>())..loadSections(),
              child: const SectionsPage(),
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
            builder: (context, _) => BlocProvider(
              create: (ctx) =>
                  ProfileCubit(ctx.read<ProfileRepository>()),
              child: const ProfilePage(),
            ),
          ),
        ],
      ),

      // --- Full-page routes (not in shell) ---
      GoRoute(
        path: '/sections/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final sectionName = state.uri.queryParameters['name'];
          return BlocProvider(
            create: (ctx) =>
                SectionBooksCubit(ctx.read<SectionRepository>())
                  ..loadBooks(id),
            child: SectionBooksPage(sectionId: id, sectionName: sectionName),
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

      // --- My Questions ---
      GoRoute(
        path: '/my-questions',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              MyQuestionsCubit(ctx.read<QaRepository>())..loadMyQuestions(),
          child: const MyQuestionsPage(),
        ),
      ),

      // --- Profile sub-routes (Tasks 5.1 / 5.2) ---
      GoRoute(
        path: '/profile/edit',
        builder: (context, _) => BlocProvider(
          create: (ctx) => ProfileCubit(ctx.read<ProfileRepository>())
            ..loadProfile(),
          child: const EditProfilePage(),
        ),
      ),
      GoRoute(
        path: '/profile/edit-password',
        builder: (context, _) => BlocProvider(
          create: (ctx) => ProfileCubit(ctx.read<ProfileRepository>())
            ..loadProfile(),
          child: const ChangePasswordPage(),
        ),
      ),

      // --- Notifications (Task 5.3) ---
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
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
            create: (ctx) => LessonCubit(
              ctx.read<LessonRepository>(),
              ctx.read<VideoStreamRepository>(),
            ),
            child: LessonPage(lessonId: lessonId, bookId: bookId),
          );
        },
      ),

      // --- Admin Shell (Task 6.1) ---
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, _) => BlocProvider(
              create: (ctx) =>
                  AdminDashboardCubit(ctx.read<AdminDashboardRepository>())
                    ..load(),
              child: const AdminDashboardPage(),
            ),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, _) => const AdminSettingsPage(),
          ),
          GoRoute(
            path: '/admin/change-password',
            builder: (context, _) => BlocProvider(
              create: (ctx) => ProfileCubit(ctx.read<ProfileRepository>())
                ..loadProfile(),
              child: const ChangePasswordPage(),
            ),
          ),
        ],
      ),

      // --- Admin: Sections (Task 6.3) ---
      GoRoute(
        path: '/admin/sections',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              AdminSectionsCubit(ctx.read<AdminSectionRepository>())
                ..load(),
          child: const AdminSectionsPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, _) => BlocProvider(
              create: (ctx) =>
                  AdminSectionsCubit(ctx.read<AdminSectionRepository>()),
              child: const AdminSectionFormPage(),
            ),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final section = state.extra as SectionEntity;
              return BlocProvider(
                create: (ctx) => AdminSectionsCubit(
                    ctx.read<AdminSectionRepository>()),
                child: AdminSectionFormPage(existing: section),
              );
            },
          ),
        ],
      ),

      // --- Admin: Books (Task 6.4) ---
      GoRoute(
        path: '/admin/books/new',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              AdminBookCubit(ctx.read<AdminBookRepository>())
                ..loadForm(),
          child: const AdminBookFormPage(),
        ),
      ),
      GoRoute(
        path: '/admin/books/:id/edit',
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return BlocProvider(
            create: (ctx) =>
                AdminBookCubit(ctx.read<AdminBookRepository>())
                  ..loadForm(bookId: bookId),
            child: AdminBookFormPage(bookId: bookId),
          );
        },
      ),

      // --- Admin: Lessons (Tasks 7.1 / 7.2 / 7.3) ---
      GoRoute(
        path: '/admin/books/:bookId/lessons',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final bookTitle = state.uri.queryParameters['title'] ?? 'الكتاب';
          return BlocProvider(
            create: (ctx) =>
                AdminLessonListCubit(ctx.read<AdminLessonRepository>())
                  ..load(bookId),
            child: AdminLessonsPage(bookId: bookId, bookTitle: bookTitle),
          );
        },
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final bookId = state.pathParameters['bookId']!;
              return BlocProvider(
                create: (ctx) =>
                    AdminLessonFormCubit(ctx.read<AdminLessonRepository>()),
                child: AdminLessonFormPage(bookId: bookId),
              );
            },
          ),
          GoRoute(
            path: ':lessonId/edit',
            builder: (context, state) {
              final bookId = state.pathParameters['bookId']!;
              final lessonId = state.pathParameters['lessonId']!;
              return BlocProvider(
                create: (ctx) =>
                    AdminLessonFormCubit(ctx.read<AdminLessonRepository>()),
                child: AdminLessonFormPage(
                    bookId: bookId, lessonId: lessonId),
              );
            },
          ),
        ],
      ),

      // --- Admin: Final Exam (Task 7.4) ---
      GoRoute(
        path: '/admin/books/:bookId/exam',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final bookTitle = state.uri.queryParameters['title'] ?? 'الكتاب';
          return BlocProvider(
            create: (ctx) =>
                AdminExamCubit(ctx.read<AdminExamRepository>())..load(bookId),
            child: AdminExamPage(bookId: bookId, bookTitle: bookTitle),
          );
        },
      ),

      // --- Admin: Per-book Dashboard (Task 7.5) ---
      GoRoute(
        path: '/admin/books/:bookId/dashboard',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final bookTitle = state.uri.queryParameters['title'] ?? 'الكتاب';
          return BlocProvider(
            create: (ctx) =>
                AdminStatsCubit(ctx.read<AdminStatsRepository>())
                  ..load(bookId),
            child:
                AdminBookDashboardPage(bookId: bookId, bookTitle: bookTitle),
          );
        },
      ),

      // --- Admin: Q&A (Task 7.6) ---
      GoRoute(
        path: '/admin/qa',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              AdminQaCubit(ctx.read<AdminQaRepository>())..load(),
          child: const AdminQaPage(),
        ),
      ),

      // --- Admin: Notifications (Task 7.7) ---
      GoRoute(
        path: '/admin/notifications',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              AdminNotificationsCubit(ctx.read<AdminNotificationsRepository>())
                ..load(),
          child: const AdminNotificationsPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, _) => BlocProvider(
              create: (ctx) => AdminNotificationsCubit(
                  ctx.read<AdminNotificationsRepository>()),
              child: const AdminNotificationFormPage(),
            ),
          ),
        ],
      ),

      // --- Admin: Banners (Task 6.5) ---
      GoRoute(
        path: '/admin/banners',
        builder: (context, _) => BlocProvider(
          create: (ctx) =>
              AdminBannerCubit(ctx.read<AdminBannerRepository>())..load(),
          child: const AdminBannersPage(),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final books =
                  (state.extra as List?)?.cast<BookEntity>() ?? <BookEntity>[];
              return BlocProvider(
                create: (ctx) =>
                    AdminBannerCubit(ctx.read<AdminBannerRepository>()),
                child: AdminBannerFormPage(books: books),
              );
            },
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              final banner = extra['banner'] as BannerEntity;
              final books =
                  (extra['books'] as List).cast<BookEntity>();
              return BlocProvider(
                create: (ctx) =>
                    AdminBannerCubit(ctx.read<AdminBannerRepository>()),
                child: AdminBannerFormPage(
                  existing: banner,
                  books: books,
                ),
              );
            },
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

  static const _routes = ['/home', '/path', '/achievements', '/profile'];
  static const _labels = ['الرئيسية', 'مساري', 'إنجازاتي', 'حسابي'];
  static const _icons = [
    Icons.home_outlined,
    Icons.route_outlined,
    Icons.star_border_rounded,
    Icons.person_outline_rounded,
  ];
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.route_rounded,
    Icons.star_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _SheikhyBottomNav(
        selectedIndex: selected,
        labels: _labels,
        icons: _icons,
        activeIcons: _activeIcons,
        onTap: (i) => context.go(_routes[i]),
      ),
    );
  }
}

// --------------- Custom heritage bottom nav ---------------

class _SheikhyBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> activeIcons;
  final ValueChanged<int> onTap;

  const _SheikhyBottomNav({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.activeIcons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(labels.length, (i) {
              final isActive = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: isActive
                          ? const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.s4,
                              vertical: AppSpacing.s2,
                            )
                          : EdgeInsets.zero,
                      decoration: isActive
                          ? BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppRadii.rLg,
                            )
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? activeIcons[i] : icons[i],
                            size: 24,
                            color: isActive
                                ? AppColors.inkInvert
                                : AppColors.inkFaint,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            labels[i],
                            style: AppTextStyles.caption.copyWith(
                              color: isActive
                                  ? AppColors.inkInvert
                                  : AppColors.inkFaint,
                              height: 1.1,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AdminShell extends StatelessWidget {
  final Widget child;
  const _AdminShell({required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/admin/settings')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Theme(
        // Gold active pill for admin shell
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: const Color(0xFFFFB300), // AppColors.gold
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.black87);
              }
              return IconThemeData(
                  color: Theme.of(context).colorScheme.onSurfaceVariant);
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex(context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'لوحة التحكم',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
          onDestinationSelected: (i) {
            const routes = ['/admin', '/admin/settings'];
            context.go(routes[i]);
          },
        ),
      ),
    );
  }
}

// --------------- Listenable bridge ---------------

class _AuthNotifier extends ChangeNotifier {
  final AuthCubit _cubit;

  // Recorded at router-build time (≈ app startup). Used to enforce a minimum
  // Flutter-splash display duration regardless of how fast auth resolves.
  final DateTime _createdAt = DateTime.now();
  static const int _minSplashMs = 2500;

  _AuthNotifier(this._cubit) {
    _cubit.stream.listen(_onState);
  }

  void _onState(dynamic state) {
    // Loading/initial states keep the splash showing — notify immediately so
    // the redirect can re-evaluate and stay on /splash.
    if (state is AuthInitial || state is AuthLoading) {
      notifyListeners();
      return;
    }
    // For any resolved state, wait out whatever is left of the minimum
    // splash time so the heritage splash is visible for at least 2.5 s.
    // Equivalent to: Future.wait([authResolved, Future.delayed(2500ms)]).
    final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
    final remaining = _minSplashMs - elapsed;
    if (remaining <= 0) {
      notifyListeners();
    } else {
      Future.delayed(Duration(milliseconds: remaining), notifyListeners);
    }
  }
}
