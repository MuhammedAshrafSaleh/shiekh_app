// test/features/admin/admin_stats_repository_test.dart
//
// Unit tests for the question-management methods added to AdminStatsRepository.
// Covers the offline guard (NetworkFailure, no Supabase call) and the
// PostgrestException → ServerFailure path for each method.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/stats/data/admin_stats_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late AdminStatsRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminStatsRepository(client, connectivity);
  });

  group('getBookQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getBookQuestions('book-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.getBookQuestions('book-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the student_questions table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.getBookQuestions('book-1');

      verify(() => client.from('student_questions')).called(1);
    });
  });

  group('answerQuestion', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.answerQuestion(
        questionId: 'q-1',
        answerText: 'answer',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.answerQuestion(
        questionId: 'q-1',
        answerText: 'answer',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('editAnswer', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.editAnswer(
        questionId: 'q-1',
        answerText: 'edited',
      );

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.editAnswer(
        questionId: 'q-1',
        answerText: 'edited',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteQuestion', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.deleteQuestion('q-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.deleteQuestion('q-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('clearBookQuestions', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.clearBookQuestions('book-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'db error'));

      final result = await repo.clearBookQuestions('book-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('queries the student_questions table', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'ok'));

      await repo.clearBookQuestions('book-1');

      verify(() => client.from('student_questions')).called(1);
    });
  });
}
