// test/features/books/book_repository_test.dart
//
// Unit tests for BookRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (isEnrolled → false, enrollInBook → AuthFailure,
//     getCompletionPercentage → 0.0)
//   • PostgrestException mapping → ServerFailure
//   • BookEntity.fromJson correctness (pure parse)
//
// Happy-path Supabase round-trips are covered by integration tests
// run against a real Supabase test project.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/books/data/book_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/book_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------
class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _offlineState = ConnectivityState(isOffline: true);
const _onlineState = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late BookRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = BookRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getBookDetails
  // -------------------------------------------------------------------------
  group('getBookDetails', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getBookDetails('any-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'relation "books" does not exist'),
      );

      final result = await repo.getBookDetails('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // isEnrolled
  // -------------------------------------------------------------------------
  group('isEnrolled', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.isEnrolled('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns Right(false) when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.isEnrolled('book-id');

      expect(result, const Right(false));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'permission denied'));

      final result = await repo.isEnrolled('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // enrollInBook
  // -------------------------------------------------------------------------
  group('enrollInBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.enrollInBook('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user (CC-20)', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.enrollInBook('book-id');

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'upsert error'));

      final result = await repo.enrollInBook('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getCompletionPercentage
  // -------------------------------------------------------------------------
  group('getCompletionPercentage', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getCompletionPercentage('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns Right(0.0) when no authenticated user (CC-1)', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getCompletionPercentage('book-id');

      expect(result, const Right(0.0));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'query error'));

      final result = await repo.getCompletionPercentage('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // hasFinalExam
  // -------------------------------------------------------------------------
  group('hasFinalExam', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.hasFinalExam('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'server error'));

      final result = await repo.hasFinalExam('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getLessonsWithProgress
  // -------------------------------------------------------------------------
  group('getLessonsWithProgress', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getLessonsWithProgress('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'lessons query error'));

      final result = await repo.getLessonsWithProgress('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // BookEntity.fromJson — pure parse tests (no Supabase)
  // -------------------------------------------------------------------------
  group('BookEntity.fromJson', () {
    final json = {
      'id': 'b1',
      'section_id': 's1',
      'title': 'شرح الأربعين النووية',
      'description': 'وصف الكتاب',
      'cover_image_url': null,
      'status': 'published',
      'is_featured': true,
      'featured_order': 1,
    };

    test('parses all fields correctly', () {
      final entity = BookEntity.fromJson(json);

      expect(entity.id, 'b1');
      expect(entity.sectionId, 's1');
      expect(entity.title, 'شرح الأربعين النووية');
      expect(entity.description, 'وصف الكتاب');
      expect(entity.coverImageUrl, isNull);
      expect(entity.status, 'published');
      expect(entity.isFeatured, true);
      expect(entity.featuredOrder, 1);
    });

    test('handles null optional fields', () {
      final minimal = {
        'id': 'b2',
        'section_id': 's1',
        'title': 'كتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'draft',
        'is_featured': false,
        'featured_order': null,
      };

      final entity = BookEntity.fromJson(minimal);

      expect(entity.description, isNull);
      expect(entity.coverImageUrl, isNull);
      expect(entity.featuredOrder, isNull);
    });
  });
}
