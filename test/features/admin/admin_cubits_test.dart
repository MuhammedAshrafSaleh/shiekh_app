// test/features/admin/admin_cubits_test.dart
//
// Cubit unit tests for Phase 6 admin — covers state sequences for:
//   • AdminDashboardCubit  (load, deleteBook)
//   • AdminSectionsCubit   (load, create, update, delete CC-3)
//   • AdminBookCubit       (loadForm new/existing, save create/update)
//   • AdminBannerCubit     (load, create CC-26, update, delete)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/banners/cubit/admin_banner_cubit.dart';
import 'package:sheikhy_app/features/admin/banners/cubit/admin_banner_state.dart';
import 'package:sheikhy_app/features/admin/banners/data/admin_banner_repository.dart';
import 'package:sheikhy_app/features/admin/books/cubit/admin_book_cubit.dart';
import 'package:sheikhy_app/features/admin/books/cubit/admin_book_state.dart';
import 'package:sheikhy_app/features/admin/books/data/admin_book_repository.dart';
import 'package:sheikhy_app/features/admin/dashboard/cubit/admin_dashboard_cubit.dart';
import 'package:sheikhy_app/features/admin/dashboard/cubit/admin_dashboard_state.dart';
import 'package:sheikhy_app/features/admin/dashboard/data/admin_dashboard_repository.dart';
import 'package:sheikhy_app/features/admin/sections/cubit/admin_sections_cubit.dart';
import 'package:sheikhy_app/features/admin/sections/cubit/admin_sections_state.dart';
import 'package:sheikhy_app/features/admin/sections/data/admin_section_repository.dart';
import 'package:sheikhy_app/models/banner_entity.dart';
import 'package:sheikhy_app/models/book_entity.dart';
import 'package:sheikhy_app/models/section_entity.dart';

// ---------------------------------------------------------------------------
// Mock repositories (mocked at repository boundary, not Supabase level)
// ---------------------------------------------------------------------------
class _MockDashboardRepo extends Mock implements AdminDashboardRepository {}
class _MockSectionRepo extends Mock implements AdminSectionRepository {}
class _MockBookRepo extends Mock implements AdminBookRepository {}
class _MockBannerRepo extends Mock implements AdminBannerRepository {}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------
const _serverFailure = ServerFailure('خطأ في الخادم');

const _stats = AdminStats(
  totalBooks: 5,
  totalStudents: 100,
  totalLessons: 20,
  pendingQa: 2,
);

const _section = SectionEntity(
  id: 'sec-1',
  name: 'العقيدة',
  icon: 'aqeedah',
  bookCount: 3,
);

const _book = BookEntity(
  id: 'book-1',
  sectionId: 'sec-1',
  title: 'كتاب الفقه',
  status: 'draft',
  reviewStatus: 'in_review',
  isFeatured: false,
);

const _banner = BannerEntity(
  id: 'ban-1',
  title: 'بانر الترحيب',
  orderIndex: 0,
  isActive: true,
);

// ===========================================================================
// AdminDashboardCubit
// ===========================================================================
void main() {
  group('AdminDashboardCubit', () {
    late _MockDashboardRepo repo;
    late AdminDashboardCubit cubit;

    setUp(() {
      repo = _MockDashboardRepo();
      cubit = AdminDashboardCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded on success', () async {
        when(() => repo.getStats())
            .thenAnswer((_) async => const Right(_stats));
        when(() => repo.getAllBooks())
            .thenAnswer((_) async => const Right([_book]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminDashboardLoading>(),
            isA<AdminDashboardLoaded>(),
          ]),
        );
        await cubit.load();
        await expectation;

        final loaded = cubit.state as AdminDashboardLoaded;
        expect(loaded.stats, _stats);
        expect(loaded.books, [_book]);
      });

      test('emits Loading then Error when getStats fails', () async {
        when(() => repo.getStats())
            .thenAnswer((_) async => const Left(_serverFailure));
        when(() => repo.getAllBooks())
            .thenAnswer((_) async => const Right([_book]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminDashboardLoading>(),
            isA<AdminDashboardError>(),
          ]),
        );
        await cubit.load();
        await expectation;

        expect((cubit.state as AdminDashboardError).message, _serverFailure.message);
      });

      test('emits Loading then Error when getAllBooks fails', () async {
        when(() => repo.getStats())
            .thenAnswer((_) async => const Right(_stats));
        when(() => repo.getAllBooks())
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminDashboardLoading>(),
            isA<AdminDashboardError>(),
          ]),
        );
        await cubit.load();
        await expectation;
      });
    });

    // ── deleteBook ──────────────────────────────────────────────────────────
    group('deleteBook', () {
      test('emits Error when delete fails', () async {
        when(() => repo.deleteBook(any()))
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminDashboardError>()),
        );
        await cubit.deleteBook('book-1');
        await expectation;
      });

      test('triggers load (emits Loading → Loaded) on delete success', () async {
        when(() => repo.deleteBook(any()))
            .thenAnswer((_) async => const Right(null));
        when(() => repo.getStats())
            .thenAnswer((_) async => const Right(_stats));
        when(() => repo.getAllBooks())
            .thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminDashboardLoading>(),
            isA<AdminDashboardLoaded>(),
          ]),
        );
        await cubit.deleteBook('book-1');
        await expectation;
      });
    });
  });

  // =========================================================================
  // AdminSectionsCubit
  // =========================================================================
  group('AdminSectionsCubit', () {
    late _MockSectionRepo repo;
    late AdminSectionsCubit cubit;

    setUp(() {
      repo = _MockSectionRepo();
      cubit = AdminSectionsCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded with sections on success', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Right([_section]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminSectionsLoading>(),
            isA<AdminSectionsLoaded>(),
          ]),
        );
        await cubit.load();
        await expectation;

        expect((cubit.state as AdminSectionsLoaded).sections, [_section]);
      });

      test('emits Loading then Error on failure', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminSectionsLoading>(),
            isA<AdminSectionsError>(),
          ]),
        );
        await cubit.load();
        await expectation;

        expect((cubit.state as AdminSectionsError).message, _serverFailure.message);
      });
    });

    // ── createSection ────────────────────────────────────────────────────────
    group('createSection', () {
      test('emits MutationSuccess on success', () async {
        when(() => repo.createSection(
              name: any(named: 'name'),
              icon: any(named: 'icon'),
              description: any(named: 'description'),
            )).thenAnswer((_) async => const Right(_section));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionMutationSuccess>()),
        );
        await cubit.createSection(name: 'العقيدة', icon: 'aqeedah');
        await expectation;
      });

      test('emits Error on failure', () async {
        when(() => repo.createSection(
              name: any(named: 'name'),
              icon: any(named: 'icon'),
              description: any(named: 'description'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionsError>()),
        );
        await cubit.createSection(name: 'العقيدة', icon: 'aqeedah');
        await expectation;
      });
    });

    // ── updateSection ────────────────────────────────────────────────────────
    group('updateSection', () {
      test('emits MutationSuccess on success', () async {
        when(() => repo.updateSection(
              id: any(named: 'id'),
              name: any(named: 'name'),
              icon: any(named: 'icon'),
              description: any(named: 'description'),
            )).thenAnswer((_) async => const Right(_section));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionMutationSuccess>()),
        );
        await cubit.updateSection(id: 'sec-1', name: 'العقيدة', icon: 'aqeedah');
        await expectation;
      });

      test('emits Error on failure', () async {
        when(() => repo.updateSection(
              id: any(named: 'id'),
              name: any(named: 'name'),
              icon: any(named: 'icon'),
              description: any(named: 'description'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionsError>()),
        );
        await cubit.updateSection(id: 'sec-1', name: 'الفقه', icon: 'fiqh');
        await expectation;
      });
    });

    // ── deleteSection — CC-3 ─────────────────────────────────────────────────
    group('deleteSection', () {
      test('emits Error on ServerFailure', () async {
        when(() => repo.deleteSection(any()))
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionsError>()),
        );
        await cubit.deleteSection('sec-1');
        await expectation;
      });

      test('CC-3: emits Error with "كتب" in message on FK violation', () async {
        const fkFailure = DeleteRestrictedFailure(
          'لا يمكن حذف القسم لأنه يحتوي على كتب',
        );
        when(() => repo.deleteSection(any()))
            .thenAnswer((_) async => const Left(fkFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminSectionsError>()),
        );
        await cubit.deleteSection('sec-1');
        await expectation;

        expect((cubit.state as AdminSectionsError).message, contains('كتب'));
      });

      test('triggers load (emits Loading → Loaded) on success', () async {
        when(() => repo.deleteSection(any()))
            .thenAnswer((_) async => const Right(null));
        when(() => repo.getSections())
            .thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminSectionsLoading>(),
            isA<AdminSectionsLoaded>(),
          ]),
        );
        await cubit.deleteSection('sec-1');
        await expectation;
      });
    });
  });

  // =========================================================================
  // AdminBookCubit
  // =========================================================================
  group('AdminBookCubit', () {
    late _MockBookRepo repo;
    late AdminBookCubit cubit;

    setUp(() {
      repo = _MockBookRepo();
      cubit = AdminBookCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── loadForm (new book) ──────────────────────────────────────────────────
    group('loadForm (new book)', () {
      test('emits Loading then FormReady with no existing book', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Right([_section]));
        when(() => repo.getFeaturedCount(excludeId: any(named: 'excludeId')))
            .thenAnswer((_) async => const Right(2));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookLoading>(),
            isA<AdminBookFormReady>(),
          ]),
        );
        await cubit.loadForm();
        await expectation;

        final ready = cubit.state as AdminBookFormReady;
        expect(ready.sections, [_section]);
        expect(ready.existing, isNull);
        expect(ready.featuredCount, 2);
      });

      test('emits Loading then Error when getSections fails', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Left(_serverFailure));
        when(() => repo.getFeaturedCount(excludeId: any(named: 'excludeId')))
            .thenAnswer((_) async => const Right(0));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookLoading>(),
            isA<AdminBookError>(),
          ]),
        );
        await cubit.loadForm();
        await expectation;
      });
    });

    // ── loadForm (edit existing book) ────────────────────────────────────────
    group('loadForm (edit existing book)', () {
      test('emits Loading then FormReady with existing book populated', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Right([_section]));
        when(() => repo.getFeaturedCount(excludeId: any(named: 'excludeId')))
            .thenAnswer((_) async => const Right(1));
        when(() => repo.getBook(any()))
            .thenAnswer((_) async => const Right(_book));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookLoading>(),
            isA<AdminBookFormReady>(),
          ]),
        );
        await cubit.loadForm(bookId: 'book-1');
        await expectation;

        final ready = cubit.state as AdminBookFormReady;
        expect(ready.existing, _book);
        expect(ready.sections, [_section]);
        expect(ready.featuredCount, 1);
      });

      test('emits Error when getBook fails', () async {
        when(() => repo.getSections())
            .thenAnswer((_) async => const Right([_section]));
        when(() => repo.getFeaturedCount(excludeId: any(named: 'excludeId')))
            .thenAnswer((_) async => const Right(0));
        when(() => repo.getBook(any()))
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookLoading>(),
            isA<AdminBookError>(),
          ]),
        );
        await cubit.loadForm(bookId: 'book-1');
        await expectation;
      });
    });

    // ── save (create new book) ───────────────────────────────────────────────
    group('save (create new book)', () {
      test('emits Saving then SaveSuccess on success', () async {
        when(() => repo.createBook(
              sectionId: any(named: 'sectionId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              coverImageUrl: any(named: 'coverImageUrl'),
              status: any(named: 'status'),
              reviewStatus: any(named: 'reviewStatus'),
              isFeatured: any(named: 'isFeatured'),
              featuredOrder: any(named: 'featuredOrder'),
            )).thenAnswer((_) async => const Right(_book));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookSaving>(),
            isA<AdminBookSaveSuccess>(),
          ]),
        );
        await cubit.save(
          sectionId: 'sec-1',
          title: 'كتاب الفقه',
          status: 'draft',
          reviewStatus: 'in_review',
          isFeatured: false,
        );
        await expectation;

        expect((cubit.state as AdminBookSaveSuccess).book, _book);
      });

      test('emits Saving then Error on failure', () async {
        when(() => repo.createBook(
              sectionId: any(named: 'sectionId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              coverImageUrl: any(named: 'coverImageUrl'),
              status: any(named: 'status'),
              reviewStatus: any(named: 'reviewStatus'),
              isFeatured: any(named: 'isFeatured'),
              featuredOrder: any(named: 'featuredOrder'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookSaving>(),
            isA<AdminBookError>(),
          ]),
        );
        await cubit.save(
          sectionId: 'sec-1',
          title: 'كتاب',
          status: 'draft',
          reviewStatus: 'in_review',
          isFeatured: false,
        );
        await expectation;
      });
    });

    // ── save (update existing book) ──────────────────────────────────────────
    group('save (update existing book)', () {
      test('emits Saving then SaveSuccess on success', () async {
        when(() => repo.updateBook(
              id: any(named: 'id'),
              sectionId: any(named: 'sectionId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              coverImageUrl: any(named: 'coverImageUrl'),
              status: any(named: 'status'),
              reviewStatus: any(named: 'reviewStatus'),
              isFeatured: any(named: 'isFeatured'),
              featuredOrder: any(named: 'featuredOrder'),
            )).thenAnswer((_) async => const Right(_book));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookSaving>(),
            isA<AdminBookSaveSuccess>(),
          ]),
        );
        await cubit.save(
          bookId: 'book-1',
          sectionId: 'sec-1',
          title: 'كتاب الفقه المحدّث',
          status: 'published',
          reviewStatus: 'completed',
          isFeatured: false,
        );
        await expectation;
      });

      test('emits Saving then Error on update failure', () async {
        when(() => repo.updateBook(
              id: any(named: 'id'),
              sectionId: any(named: 'sectionId'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              coverImageUrl: any(named: 'coverImageUrl'),
              status: any(named: 'status'),
              reviewStatus: any(named: 'reviewStatus'),
              isFeatured: any(named: 'isFeatured'),
              featuredOrder: any(named: 'featuredOrder'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBookSaving>(),
            isA<AdminBookError>(),
          ]),
        );
        await cubit.save(
          bookId: 'book-1',
          sectionId: 'sec-1',
          title: 'كتاب',
          status: 'draft',
          reviewStatus: 'in_review',
          isFeatured: false,
        );
        await expectation;
      });
    });
  });

  // =========================================================================
  // AdminBannerCubit
  // =========================================================================
  group('AdminBannerCubit', () {
    late _MockBannerRepo repo;
    late AdminBannerCubit cubit;

    setUp(() {
      repo = _MockBannerRepo();
      cubit = AdminBannerCubit(repo);
    });

    tearDown(() => cubit.close());

    // ── load ────────────────────────────────────────────────────────────────
    group('load', () {
      test('emits Loading then Loaded with banners and books on success', () async {
        when(() => repo.getBanners())
            .thenAnswer((_) async => const Right([_banner]));
        when(() => repo.getPublishedBooks())
            .thenAnswer((_) async => const Right([_book]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBannerLoading>(),
            isA<AdminBannerLoaded>(),
          ]),
        );
        await cubit.load();
        await expectation;

        final loaded = cubit.state as AdminBannerLoaded;
        expect(loaded.banners, [_banner]);
        expect(loaded.books, [_book]);
      });

      test('emits Loading then Error when getBanners fails', () async {
        when(() => repo.getBanners())
            .thenAnswer((_) async => const Left(_serverFailure));
        when(() => repo.getPublishedBooks())
            .thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBannerLoading>(),
            isA<AdminBannerError>(),
          ]),
        );
        await cubit.load();
        await expectation;
      });

      test('emits Loading then Error when getPublishedBooks fails', () async {
        when(() => repo.getBanners())
            .thenAnswer((_) async => const Right([]));
        when(() => repo.getPublishedBooks())
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBannerLoading>(),
            isA<AdminBannerError>(),
          ]),
        );
        await cubit.load();
        await expectation;
      });
    });

    // ── createBanner — CC-26 nullable target ─────────────────────────────────
    group('createBanner', () {
      test('emits MutationSuccess on success', () async {
        when(() => repo.createBanner(
              title: any(named: 'title'),
              description: any(named: 'description'),
              imageUrl: any(named: 'imageUrl'),
              linkedBookId: any(named: 'linkedBookId'),
              externalLink: any(named: 'externalLink'),
              orderIndex: any(named: 'orderIndex'),
              isActive: any(named: 'isActive'),
            )).thenAnswer((_) async => const Right(_banner));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerMutationSuccess>()),
        );
        await cubit.createBanner(
          title: 'بانر جديد',
          orderIndex: 0,
          isActive: true,
        );
        await expectation;
      });

      test('CC-26: emits MutationSuccess with null linkedBookId and externalLink', () async {
        when(() => repo.createBanner(
              title: any(named: 'title'),
              description: any(named: 'description'),
              imageUrl: any(named: 'imageUrl'),
              linkedBookId: any(named: 'linkedBookId'),
              externalLink: any(named: 'externalLink'),
              orderIndex: any(named: 'orderIndex'),
              isActive: any(named: 'isActive'),
            )).thenAnswer((_) async => const Right(_banner));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerMutationSuccess>()),
        );
        await cubit.createBanner(
          title: 'بانر بدون رابط',
          orderIndex: 1,
          isActive: false,
          linkedBookId: null,
          externalLink: null,
        );
        await expectation;
      });

      test('emits Error on failure', () async {
        when(() => repo.createBanner(
              title: any(named: 'title'),
              description: any(named: 'description'),
              imageUrl: any(named: 'imageUrl'),
              linkedBookId: any(named: 'linkedBookId'),
              externalLink: any(named: 'externalLink'),
              orderIndex: any(named: 'orderIndex'),
              isActive: any(named: 'isActive'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerError>()),
        );
        await cubit.createBanner(
          title: 'بانر',
          orderIndex: 0,
          isActive: true,
        );
        await expectation;
      });
    });

    // ── updateBanner ─────────────────────────────────────────────────────────
    group('updateBanner', () {
      test('emits MutationSuccess on success', () async {
        when(() => repo.updateBanner(
              id: any(named: 'id'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              imageUrl: any(named: 'imageUrl'),
              linkedBookId: any(named: 'linkedBookId'),
              externalLink: any(named: 'externalLink'),
              orderIndex: any(named: 'orderIndex'),
              isActive: any(named: 'isActive'),
            )).thenAnswer((_) async => const Right(_banner));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerMutationSuccess>()),
        );
        await cubit.updateBanner(
          id: 'ban-1',
          title: 'بانر محدّث',
          orderIndex: 0,
          isActive: true,
        );
        await expectation;
      });

      test('emits Error on failure', () async {
        when(() => repo.updateBanner(
              id: any(named: 'id'),
              title: any(named: 'title'),
              description: any(named: 'description'),
              imageUrl: any(named: 'imageUrl'),
              linkedBookId: any(named: 'linkedBookId'),
              externalLink: any(named: 'externalLink'),
              orderIndex: any(named: 'orderIndex'),
              isActive: any(named: 'isActive'),
            )).thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerError>()),
        );
        await cubit.updateBanner(
          id: 'ban-1',
          title: 'بانر',
          orderIndex: 0,
          isActive: false,
        );
        await expectation;
      });
    });

    // ── deleteBanner ─────────────────────────────────────────────────────────
    group('deleteBanner', () {
      test('emits Error on failure', () async {
        when(() => repo.deleteBanner(any()))
            .thenAnswer((_) async => const Left(_serverFailure));

        final expectation = expectLater(
          cubit.stream,
          emits(isA<AdminBannerError>()),
        );
        await cubit.deleteBanner('ban-1');
        await expectation;
      });

      test('triggers load (emits Loading → Loaded) on success', () async {
        when(() => repo.deleteBanner(any()))
            .thenAnswer((_) async => const Right(null));
        when(() => repo.getBanners())
            .thenAnswer((_) async => const Right([]));
        when(() => repo.getPublishedBooks())
            .thenAnswer((_) async => const Right([]));

        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            isA<AdminBannerLoading>(),
            isA<AdminBannerLoaded>(),
          ]),
        );
        await cubit.deleteBanner('ban-1');
        await expectation;
      });
    });
  });
}
