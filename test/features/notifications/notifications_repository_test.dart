// test/features/notifications/notifications_repository_test.dart
//
// Unit tests for NotificationsRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (AuthFailure)
//   • PostgrestException mapping → ServerFailure
//   • NotificationEntity.fromJson parsing + isRead flag propagation
//   • markAllRead: skips when empty list (returns Right(null) directly)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/features/notifications/data/notifications_repository.dart';
import 'package:sheikhy_app/models/notification_entity.dart';
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
// Constants
// ---------------------------------------------------------------------------
const _offlineState = ConnectivityState(isOffline: true);
const _onlineState = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late NotificationsRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = NotificationsRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getNotifications
  // -------------------------------------------------------------------------
  group('getNotifications', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getNotifications();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getNotifications();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'notifications query error'),
      );

      final result = await repo.getNotifications();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // markAllRead
  // -------------------------------------------------------------------------
  group('markAllRead', () {
    test('returns Right(null) immediately when list is empty', () async {
      when(() => connectivity.state).thenReturn(_onlineState);

      final result = await repo.markAllRead([]);

      expect(result, const Right<Failure, void>(null));
      verifyNever(() => client.from(any()));
    });

    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.markAllRead(['notif-1', 'notif-2']);

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.markAllRead(['notif-1']);

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'upsert error'),
      );

      final result = await repo.markAllRead(['notif-1']);

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // markRead
  // -------------------------------------------------------------------------
  group('markRead', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.markRead('notif-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.markRead('notif-1');

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(() => client.from(any())).thenThrow(
        const PostgrestException(message: 'upsert error'),
      );

      final result = await repo.markRead('notif-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // NotificationEntity.fromJson — pure parse tests
  // -------------------------------------------------------------------------
  group('NotificationEntity.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'n-1',
        'type': 'new_lesson',
        'title': 'درس جديد',
        'body': 'تم نشر درس جديد في كتاب الفقه',
        'link_url': '/books/book-uuid',
        'send_at': '2026-07-01T10:00:00.000Z',
        'created_at': '2026-07-01T09:50:00.000Z',
        'notification_reads': [],
      };

      final entity = NotificationEntity.fromJson(json, isRead: false);

      expect(entity.id, 'n-1');
      expect(entity.type, 'new_lesson');
      expect(entity.title, 'درس جديد');
      expect(entity.body, 'تم نشر درس جديد في كتاب الفقه');
      expect(entity.linkUrl, '/books/book-uuid');
      expect(entity.isRead, false);
    });

    test('isRead=true when explicitly passed', () {
      final json = {
        'id': 'n-2',
        'type': 'general',
        'title': 'إشعار عام',
        'body': 'محتوى',
        'link_url': null,
        'send_at': '2026-07-01T10:00:00.000Z',
        'created_at': '2026-07-01T09:50:00.000Z',
      };

      final entity = NotificationEntity.fromJson(json, isRead: true);

      expect(entity.isRead, true);
    });

    test('copyWith correctly updates isRead', () {
      final json = {
        'id': 'n-3',
        'type': 'reminder',
        'title': 'تذكير',
        'body': 'تذكير بالمذاكرة',
        'link_url': null,
        'send_at': '2026-07-01T10:00:00.000Z',
        'created_at': '2026-07-01T09:50:00.000Z',
      };

      final entity = NotificationEntity.fromJson(json, isRead: false);
      final updated = entity.copyWith(isRead: true);

      expect(entity.isRead, false);
      expect(updated.isRead, true);
      expect(updated.id, entity.id);
    });

    test('two identical entities are equal (Equatable)', () {
      final json = {
        'id': 'n-4',
        'type': 'achievement',
        'title': 'إنجاز',
        'body': 'حصلت على شهادة',
        'link_url': null,
        'send_at': '2026-07-01T10:00:00.000Z',
        'created_at': '2026-07-01T09:50:00.000Z',
      };

      expect(
        NotificationEntity.fromJson(json, isRead: false),
        equals(NotificationEntity.fromJson(json, isRead: false)),
      );
    });

    test('defaults type to "general" when null in json', () {
      final json = {
        'id': 'n-5',
        'type': null,
        'title': 'Test',
        'body': 'Body',
        'link_url': null,
        'send_at': '2026-07-01T10:00:00.000Z',
        'created_at': '2026-07-01T09:50:00.000Z',
      };

      final entity = NotificationEntity.fromJson(json);

      expect(entity.type, 'general');
    });
  });
}
