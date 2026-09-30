// test/features/admin/shared/question_bank_repository_test.dart
//
// Unit tests for QuestionBankRepository — the shared read layer for the bank
// import drill-down. Covers the offline guard and the PostgrestException →
// ServerFailure branch for both methods (RPC + per-lesson query).
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/shared/data/question_bank_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:sheikhy_app/models/bank_lesson_summary_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late QuestionBankRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = QuestionBankRepository(client, connectivity);
  });

  group('getBankLessonSummaries', () {
    test('returns NetworkFailure when offline, without calling rpc', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getBankLessonSummaries('book-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.rpc(any(), params: any(named: 'params')),
      ).thenThrow(const PostgrestException(message: 'boom'));

      final result = await repo.getBankLessonSummaries('book-1');

      expect(result, isA<Left<Failure, List<BankLessonSummaryEntity>>>());
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getLessonBankQuestions', () {
    test('returns NetworkFailure when offline, without querying', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getLessonBankQuestions('lesson-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'boom'));

      final result = await repo.getLessonBankQuestions('lesson-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('BankLessonSummaryEntity.fromJson', () {
    test('parses an rpc row (approved_count as num)', () {
      final e = BankLessonSummaryEntity.fromJson(const {
        'lesson_id': 'l-1',
        'title': 'مقدمة',
        'order_index': 2,
        'approved_count': 12,
      });

      expect(e.lessonId, 'l-1');
      expect(e.title, 'مقدمة');
      expect(e.orderIndex, 2);
      expect(e.approvedCount, 12);
    });
  });
}
