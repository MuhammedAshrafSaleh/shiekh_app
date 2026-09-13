// test/features/admin/admin_banner_repository_test.dart
//
// Unit tests for AdminBannerRepository — covers:
//   • Offline guard → NetworkFailure
//   • PostgrestException → ServerFailure
//   • CC-26: banner target is nullable (null linkedBookId + null externalLink allowed)
//   • BannerEntity.fromJson — pure parse
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/banners/data/admin_banner_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/banner_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late AdminBannerRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminBannerRepository(client, connectivity);
  });

  // ── getBanners ────────────────────────────────────────────────────────────
  group('getBanners', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getBanners();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getBanners();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries home_banners table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.getBanners();

      verify(() => client.from('home_banners')).called(1);
    });
  });

  // ── getPublishedBooks ─────────────────────────────────────────────────────
  group('getPublishedBooks', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getPublishedBooks();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'error'));

      final result = await repo.getPublishedBooks();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── createBanner — CC-26: nullable target ─────────────────────────────────
  group('createBanner', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.createBanner(
        title: 'بانر جديد',
        orderIndex: 0,
        isActive: true,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'insert error'));

      final result = await repo.createBanner(
        title: 'بانر',
        orderIndex: 1,
        isActive: true,
        // CC-26: both targets nullable — no linked book, no external link
        linkedBookId: null,
        externalLink: null,
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('CC-26: queries home_banners even when target is null', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.createBanner(
        title: 'بانر بدون رابط',
        orderIndex: 0,
        isActive: false,
        linkedBookId: null,
        externalLink: null,
      );

      verify(() => client.from('home_banners')).called(1);
    });
  });

  // ── updateBanner ──────────────────────────────────────────────────────────
  group('updateBanner', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.updateBanner(
        id: 'banner-id',
        title: 'بانر محدّث',
        orderIndex: 0,
        isActive: true,
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'update error'));

      final result = await repo.updateBanner(
        id: 'banner-id',
        title: 'بانر محدّث',
        orderIndex: 2,
        isActive: false,
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── deleteBanner ──────────────────────────────────────────────────────────
  group('deleteBanner', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteBanner('banner-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'delete error'));

      final result = await repo.deleteBanner('banner-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries home_banners table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.deleteBanner('banner-id');

      verify(() => client.from('home_banners')).called(1);
    });
  });

  // ── BannerEntity.fromJson — pure parse ────────────────────────────────────
  group('BannerEntity.fromJson', () {
    test('parses a banner with book link correctly', () {
      final json = {
        'id': 'ban-1',
        'title': 'بانر الترحيب',
        'description': 'مرحباً بكم',
        'image_url': 'https://example.com/banner.jpg',
        'linked_book_id': 'book-123',
        'external_link': null,
        'order_index': 0,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entity = BannerEntity.fromJson(json);

      expect(entity.id, 'ban-1');
      expect(entity.title, 'بانر الترحيب');
      expect(entity.linkedBookId, 'book-123');
      expect(entity.externalLink, isNull);
      expect(entity.orderIndex, 0);
      expect(entity.isActive, true);
    });

    test(
      'CC-26: parses a banner with null linked_book_id and null external_link',
      () {
        final json = {
          'id': 'ban-2',
          'title': 'بانر إعلاني',
          'description': null,
          'image_url': null,
          'linked_book_id': null, // CC-26: nullable target
          'external_link': null, // CC-26: nullable target
          'order_index': 1,
          'is_active': false,
          'created_at': '2024-01-01T00:00:00.000Z',
        };

        final entity = BannerEntity.fromJson(json);

        expect(entity.linkedBookId, isNull);
        expect(entity.externalLink, isNull);
        expect(entity.isActive, false);
      },
    );

    test('parses a banner with external link', () {
      final json = {
        'id': 'ban-3',
        'title': 'بث مباشر',
        'description': null,
        'image_url': null,
        'linked_book_id': null,
        'external_link': 'https://youtube.com/live/abc',
        'order_index': 2,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entity = BannerEntity.fromJson(json);

      expect(entity.externalLink, 'https://youtube.com/live/abc');
      expect(entity.linkedBookId, isNull);
    });
  });
}
