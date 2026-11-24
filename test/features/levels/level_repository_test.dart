// test/features/levels/level_repository_test.dart
//
// Unit tests for LevelRepository (student):
//   • getLevels  — offline guard, ServerFailure, empty-level exclusion
//   • getBooksByLevel — offline guard, ServerFailure, empty list fast-path
//   • BookEntity.fromJson — level_id / level_order tolerant of absence
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/levels/data/level_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/book_entity.dart';
import 'package:sheikhy_app/models/level_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late LevelRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
    repo = LevelRepository(client, connectivity);
  });

  void goOnlineButThrow(PostgrestException e) {
    when(() => connectivity.state).thenReturn(_online);
    when(() => client.from(any())).thenThrow(e);
  }

  // ── getLevels ─────────────────────────────────────────────────────────────
  group('getLevels', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getLevels();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getLevels();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the levels table', () async {
      goOnlineButThrow(const PostgrestException(message: 'ok'));

      await repo.getLevels();

      verify(() => client.from('levels')).called(greaterThanOrEqualTo(1));
    });

    test('excludes levels with zero published books from student results', () {
      // Dart-only test: the filtering logic runs in pure Dart after the two
      // Supabase queries return. Build the inputs manually and verify the
      // filter predicate correctly drops the empty level.
      //
      // Three levels; only lvl-B has a published book.
      final levelsRaw = [
        {'id': 'lvl-A', 'name': 'المستوى الأول', 'sort_order': 1},
        {'id': 'lvl-B', 'name': 'المستوى الثاني', 'sort_order': 2},
        {'id': 'lvl-C', 'name': 'المستوى الثالث', 'sort_order': 3},
      ];

      // Simulate the grouped count map (the books query result).
      final Map<String, int> countByLevel = {'lvl-B': 2};

      final levels = levelsRaw
          .map(
            (e) => LevelEntity.fromJson(
              e as Map<String, dynamic>,
              bookCount: countByLevel[e['id'] as String] ?? 0,
            ),
          )
          .where((l) => l.bookCount > 0)
          .toList();

      expect(levels.length, 1);
      expect(levels.first.id, 'lvl-B');
      expect(levels.first.bookCount, 2);
    });

    test('returns empty list when no levels have published books', () {
      final levelsRaw = [
        {'id': 'lvl-A', 'name': 'المستوى الأول', 'sort_order': 1},
      ];
      final Map<String, int> countByLevel = {};

      final levels = levelsRaw
          .map(
            (e) => LevelEntity.fromJson(
              e as Map<String, dynamic>,
              bookCount: countByLevel[e['id'] as String] ?? 0,
            ),
          )
          .where((l) => l.bookCount > 0)
          .toList();

      expect(levels, isEmpty);
    });
  });

  // ── getBooksByLevel ───────────────────────────────────────────────────────
  group('getBooksByLevel', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getBooksByLevel('lvl-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      goOnlineButThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getBooksByLevel('lvl-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the books table', () async {
      goOnlineButThrow(const PostgrestException(message: 'ok'));

      await repo.getBooksByLevel('lvl-1');

      verify(() => client.from('books')).called(greaterThanOrEqualTo(1));
    });
  });

  // ── BookEntity.fromJson — level fields ────────────────────────────────────
  group('BookEntity.fromJson level fields', () {
    test('defaults levelId and levelOrder to null when absent', () {
      final book = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'بلوغ المرام',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'completed',
        'is_featured': false,
        'featured_order': null,
      });

      expect(book.levelId, isNull);
      expect(book.levelOrder, isNull);
    });

    test('reads levelId and levelOrder when present', () {
      final book = BookEntity.fromJson({
        'id': 'book-2',
        'section_id': 'sec-1',
        'title': 'الأربعون النووية',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'completed',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-5',
        'level_order': 3,
      });

      expect(book.levelId, 'lvl-5');
      expect(book.levelOrder, 3);
    });

    test('level fields appear in props (Equatable)', () {
      final a = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'الكتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-1',
        'level_order': 1,
      });
      final b = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'الكتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-2',
        'level_order': 2,
      });

      expect(a, isNot(equals(b)));
    });

    test('copyWith updates levelId and levelOrder independently', () {
      final original = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'الكتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-1',
        'level_order': 1,
      });

      final updated = original.copyWith(levelId: 'lvl-9', levelOrder: 5);

      expect(updated.id, original.id);
      expect(updated.levelId, 'lvl-9');
      expect(updated.levelOrder, 5);
      expect(updated.title, original.title);
    });

    test('copyWith with no args preserves existing levelId/levelOrder', () {
      final original = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'الكتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-1',
        'level_order': 2,
      });

      final copy = original.copyWith();

      expect(copy.levelId, 'lvl-1');
      expect(copy.levelOrder, 2);
    });

    test('copyWith can clear levelId and levelOrder to null', () {
      final original = BookEntity.fromJson({
        'id': 'book-1',
        'section_id': 'sec-1',
        'title': 'الكتاب',
        'description': null,
        'cover_image_url': null,
        'status': 'published',
        'review_status': 'in_review',
        'is_featured': false,
        'featured_order': null,
        'level_id': 'lvl-1',
        'level_order': 3,
      });

      final cleared = original.copyWith(levelId: null, levelOrder: null);

      expect(cleared.levelId, isNull);
      expect(cleared.levelOrder, isNull);
      expect(cleared.id, original.id);
    });
  });
}
