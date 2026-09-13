// test/features/certificates/certificate_repository_test.dart
//
// Unit tests for CertificateRepository — covers:
//   • Offline guard (NetworkFailure before any Supabase call)
//   • Null-user guard (getCertificates → AuthFailure, getCertificateForBook → null)
//   • PostgrestException mapping → ServerFailure
//   • CertificateEntity.fromJson correctness (pure parse, incl. null optional fields)
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/certificates/data/certificate_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/certificate_entity.dart';
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
  late CertificateRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    when(() => client.auth).thenReturn(auth);
    repo = CertificateRepository(client, connectivity);
  });

  // -------------------------------------------------------------------------
  // getCertificates
  // -------------------------------------------------------------------------
  group('getCertificates', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getCertificates();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns AuthFailure when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getCertificates();

      expect(result, const Left(AuthFailure('يجب تسجيل الدخول أولاً')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'certs table error'));

      final result = await repo.getCertificates();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getCertificateForBook
  // -------------------------------------------------------------------------
  group('getCertificateForBook', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offlineState);

      final result = await repo.getCertificateForBook('book-id');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });

    test('returns Right(null) when no authenticated user', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo.getCertificateForBook('book-id');

      expect(result, const Right(null));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure when PostgrestException is thrown', () async {
      when(() => connectivity.state).thenReturn(_onlineState);
      when(() => auth.currentUser).thenReturn(_FakeUser());
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'query error'));

      final result = await repo.getCertificateForBook('book-id');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // CertificateEntity.fromJson — pure parse tests
  // -------------------------------------------------------------------------
  group('CertificateEntity.fromJson', () {
    test('parses a complete certificate correctly', () {
      final json = {
        'id': 'cert-1',
        'user_id': 'u-1',
        'book_id': 'b-1',
        'final_exam_attempt_id': 'att-1',
        'final_score': 92,
        'grade_label': 'ممتاز',
        'issued_at': '2026-07-01T12:00:00.000Z',
        'pdf_url': null,
      };

      final entity = CertificateEntity.fromJson(json);

      expect(entity.id, 'cert-1');
      expect(entity.userId, 'u-1');
      expect(entity.bookId, 'b-1');
      expect(entity.finalExamAttemptId, 'att-1');
      expect(entity.finalScore, 92);
      expect(entity.gradeLabel, 'ممتاز');
      expect(entity.issuedAt, DateTime.utc(2026, 7, 1, 12, 0));
      expect(entity.pdfUrl, isNull);
    });

    test('handles all null optional fields', () {
      final json = {
        'id': 'cert-2',
        'user_id': 'u-1',
        'book_id': 'b-2',
        'final_exam_attempt_id': null,
        'final_score': 70,
        'grade_label': null,
        'issued_at': '2026-06-15T08:30:00.000Z',
        'pdf_url': null,
      };

      final entity = CertificateEntity.fromJson(json);

      expect(entity.finalExamAttemptId, isNull);
      expect(entity.gradeLabel, isNull);
      expect(entity.pdfUrl, isNull);
    });

    test('grade bands are parsed as-is (banding decided server-side)', () {
      for (final label in ['ممتاز', 'جيد جداً', 'جيد']) {
        final json = {
          'id': 'cert-x',
          'user_id': 'u-1',
          'book_id': 'b-1',
          'final_exam_attempt_id': null,
          'final_score': 75,
          'grade_label': label,
          'issued_at': '2026-07-01T00:00:00.000Z',
          'pdf_url': null,
        };
        expect(CertificateEntity.fromJson(json).gradeLabel, label);
      }
    });

    test('Equatable props make two identical entities equal', () {
      final json = {
        'id': 'cert-3',
        'user_id': 'u-1',
        'book_id': 'b-1',
        'final_exam_attempt_id': null,
        'final_score': 80,
        'grade_label': 'جيد جداً',
        'issued_at': '2026-07-01T00:00:00.000Z',
        'pdf_url': null,
      };

      expect(
        CertificateEntity.fromJson(json),
        equals(CertificateEntity.fromJson(json)),
      );
    });
  });
}
