
      // --- Lesson (Tasks 3.3–3.8) ---
      GoRoute(
        path: '/lessons/:id',
        builder: (context, state) {
          final lessonId = state.pathParameters['id']!;
          final bookId = state.uri.queryParameters['bookId'] ?? '';
          final seekToSeconds = int.tryParse(
            state.uri.queryParameters['t'] ?? '',
          );
          return BlocProvider(
            create: (ctx) => LessonCubit(
              ctx.read<LessonRepository>(),
              ctx.read<VideoStreamRepository>(),
            ),
            child: LessonPage(
              lessonId: lessonId,
              bookId: bookId,
              seekToSeconds: seekToSeconds,
            ),
          );
        },
      ),

      // --- Admin Shell (Task 6.1) ---
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [