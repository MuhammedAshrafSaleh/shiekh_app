// test/features/admin/lessons/admin_lesson_repository_test.dart
//
// Unit tests for AdminLessonRepository.generateQuestions — the generate-questions
// Edge Function call. Covers the offline guard, the success path, and each
// failure branch (function error body, client-side timeout, transport failure,
// network loss).
import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// http is a transitive dep (functions_client); used only to construct a
// transport-level ClientException for the failure-path test.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/lessons/data/admin_lesson_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockFunctionsClient functions;
  late _MockGoTrueClient auth;
  late _MockConnectivityCubit connectivity;
  late AdminLessonRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    auth = _MockGoTrueClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminLessonRepository(client, connectivity);
    when(() => client.functions).thenReturn(functions);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
  });

  Future<Either<Failure, dynamic>> callGenerate() => repo.generateQuestions(
    lessonId: 'lesson-1',
    transcriptText: 'نص المحاضرة',
    requestedCount: 10,
    difficultyMix: const {'easy': 4, 'medium': 4, 'hard': 2},
  );

  group('generateQuestions', () {
    test('returns NetworkFailure when offline, without invoking', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await callGenerate();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('returns the parsed result on success', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer(
        (_) async => const FunctionResponse(
          data: {'job_id': 'job-1', 'inserted_count': 12},
          status: 200,
        ),
      );

      final result = await callGenerate();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('expected Right'),
        (r) {
          expect(r.jobId, 'job-1');
          expect(r.insertedCount, 12);
        },
      );
      verify(
        () => functions.invoke('generate-questions', body: any(named: 'body')),
      ).called(1);
    });

    test('maps FunctionException {error} body to ServerFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(
        const FunctionException(
          status: 400,
          details: {'error': 'النص قصير جدًا'},
        ),
      );

      final result = await callGenerate();

      expect(result, const Left(ServerFailure('النص قصير جدًا')));
    });

    test('maps TimeoutException to ServerFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(TimeoutException('too long'));

      final result = await callGenerate();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps transport ClientException to NetworkFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(ClientException('connection reset'));

      final result = await callGenerate();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps SocketException to NetworkFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(const SocketException('no network'));

      final result = await callGenerate();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });
  });

  Future<Either<Failure, dynamic>> callTranscribe() => repo.transcribeLesson(
    lessonId: 'lesson-1',
    sourceType: 'youtube',
    sourceUrl: 'https://youtu.be/abc',
  );

  group('transcribeLesson', () {
    test('returns NetworkFailure when offline, without invoking', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await callTranscribe();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('returns the parsed transcript on success', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
        (_) async => const FunctionResponse(
          data: {'job_id': 'job-9', 'transcript_text': 'النص المُفرَّغ'},
          status: 200,
        ),
      );

      final result = await callTranscribe();

      expect(result.isRight(), true);
      result.fold((_) => fail('expected Right'), (r) {
        expect(r.jobId, 'job-9');
        expect(r.transcriptText, 'النص المُفرَّغ');
      });
      verify(
        () => functions.invoke('transcribe-lesson', body: any(named: 'body')),
      ).called(1);
    });

    test('maps FunctionException {error} body to ServerFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
        const FunctionException(
          status: 400,
          details: {'error': 'الفيديو أطول من الحد المسموح'},
        ),
      );

      final result = await callTranscribe();

      expect(
        result,
        const Left(ServerFailure('الفيديو أطول من الحد المسموح')),
      );
    });

    test('maps TimeoutException to ServerFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(TimeoutException('too long'));

      final result = await callTranscribe();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps transport ClientException to NetworkFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(ClientException('connection reset'));

      final result = await callTranscribe();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps SocketException to NetworkFailure', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(const SocketException('no network'));

      final result = await callTranscribe();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
    });
  });

  group('approveQuestion', () {
    test('returns NetworkFailure when offline, without touching db', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.approveQuestion('q-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'update error'));

      final result = await repo.approveQuestion('q-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('approveAllForLesson', () {
    test('returns NetworkFailure when offline, without touching db', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.approveAllForLesson('lesson-1');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.from(any()));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      when(
        () => client.from(any()),
      ).thenThrow(const PostgrestException(message: 'bulk update error'));

      final result = await repo.approveAllForLesson('lesson-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
