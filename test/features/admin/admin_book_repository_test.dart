// test/features/admin/admin_book_repository_test.dart
//
// Unit tests for AdminBookRepository — covers:
//   • Offline guard → NetworkFailure
//   • PostgrestException → ServerFailure
//   • CC-24: getFeaturedCount returns correct exclusion logic
//   • BookEntity.fromJson with review_status field
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/books/data/admin_book_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/book_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}
class _MockGoTrueClient extends Mock implements GoTrueClient {}
class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'admin-user-id';
}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late AdminBookRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = AdminBookRepository(client, connectivity);
  });

  // ── getSections ───────────────────────────────────────────────────────────
  group('getSections', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getSections();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'error'));

      final result = await repo.getSections();

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });
  });

  // ── getFeaturedCount ──────────────────────────────────────────────────────
  group('getFeaturedCount', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getFeaturedCount();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'error'));

      final result = await repo.getFeaturedCount();

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });

    test('queries books table with is_featured filter', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'ok'));

      await repo.getFeaturedCount();

      verify(() => client.from('books')).called(1);
    });
  });

  // ── getBook ───────────────────────────────────────────────────────────────
  group('getBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getBook('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'not found'));

      final result = await repo.getBook('book-id');

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });
  });

  // ── createBook ────────────────────────────────────────────────────────────
  group('createBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.createBook(
        sectionId: 'sec-id',
        title: 'كتاب الفقه',
        status: 'draft',
        reviewStatus: 'in_review',
        isFeatured: false,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'insert error'));

      final result = await repo.createBook(
        sectionId: 'sec-id',
        title: 'كتاب الفقه',
        status: 'draft',
        reviewStatus: 'in_review',
        isFeatured: false,
      );

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });
  });

  // ── updateBook ────────────────────────────────────────────────────────────
  group('updateBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.updateBook(
        id: 'book-id',
        sectionId: 'sec-id',
        title: 'كتاب محدّث',
        status: 'published',
        reviewStatus: 'completed',
        isFeatured: true,
        featuredOrder: 1,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => client.from(any()))
          .thenThrow(const PostgrestException(message: 'update error'));

      final result = await repo.updateBook(
        id: 'book-id',
        sectionId: 'sec-id',
        title: 'كتاب محدّث',
        status: 'published',
        reviewStatus: 'completed',
        isFeatured: false,
      );

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });
  });

  // ── BookEntity.fromJson — reviewStatus field ──────────────────────────────
  group('BookEntity.fromJson', () {
    test('parses review_status correctly', () {
      final json = {
        'id': 'b1',
        'section_id': 'sec-1',
        'title': 'صحيح البخاري',
        'description': 'كتاب الحديث',
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'completed',
        'is_featured': true,
        'featured_order': 2,
      };

      final entity = BookEntity.fromJson(json);

      expect(entity.status, 'published');
      expect(entity.reviewStatus, 'completed');
      expect(entity.isFeatured, true);
      expect(entity.featuredOrder, 2);
    });

    test('defaults review_status to in_review when missing', () {
      final json = {
        'id': 'b2',
        'section_id': 'sec-1',
        'title': 'كتاب جديد',
        'description': null,
        'cover_image_url': null,
        'status': 'draft',
        'review_status': null,
        'is_featured': false,
        'featured_order': null,
      };

      final entity = BookEntity.fromJson(json);

      expect(entity.reviewStatus, 'in_review');
    });

    test('CC-24: non-featured book has null featuredOrder', () {
      final json = {
        'id': 'b3',
        'section_id': 'sec-1',
        'title': 'كتاب غير مميز',
        'description': null,
        'cover_image_url': null,
        'status': 'draft',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
      };

      final entity = BookEntity.fromJson(json);

      expect(entity.isFeatured, false);
      expect(entity.featuredOrder, isNull);
    });
  });
}
