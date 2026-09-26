                create: (_) => PathRepository(supabase, connectivity),
              ),
              RepositoryProvider<SectionRepository>(
                create: (_) => SectionRepository(supabase, connectivity),
              ),
              RepositoryProvider<OnboardingRepository>(
                create: (_) => OnboardingRepository(supabase, connectivity),
              ),
              RepositoryProvider<BookRepository>(
                create: (_) => BookRepository(supabase, connectivity),
              ),
              RepositoryProvider<LessonRepository>(
                create: (_) => LessonRepository(supabase, connectivity),
              ),
              RepositoryProvider<VideoStreamRepository>(
                create: (_) => VideoStreamRepository(),
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