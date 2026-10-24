// test/features/admin/ai_settings/admin_ai_settings_repository_test.dart
//
// Unit tests for AdminAiSettingsRepository. Covers the offline guard
// (NetworkFailure, no RPC call) and the PostgrestException → ServerFailure path
// for each method, plus GeminiKeyStatus.fromJson parsing/masking.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/admin/ai_settings/data/admin_ai_settings_repository.dart';
import 'package:sheikhy_app/features/notifications/cubit/connectivity_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

const _offline = ConnectivityState(isOffline: true);
const _online = ConnectivityState(isOffline: false);

void main() {
  late _MockSupabaseClient client;
  late _MockConnectivityCubit connectivity;
  late AdminAiSettingsRepository repo;

  setUp(() {
    client = _MockSupabaseClient();
    connectivity = _MockConnectivityCubit();
    repo = AdminAiSettingsRepository(client, connectivity);
  });

  void rpcThrows() {
    when(() => client.rpc(any(), params: any(named: 'params')))
        .thenThrow(const PostgrestException(message: 'db error'));
  }

  group('getGeminiKeyStatus', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.getGeminiKeyStatus();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      final result = await repo.getGeminiKeyStatus();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('calls the get_secret_status RPC', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      await repo.getGeminiKeyStatus();

      verify(() => client.rpc('get_secret_status',
          params: {'p_key': 'gemini_api_key'})).called(1);
    });
  });

  group('setGeminiKey', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.setGeminiKey('abc123');

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      final result = await repo.setGeminiKey('abc123');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('calls set_app_secret with the trimmed value', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      await repo.setGeminiKey('  abc123  ');

      verify(() => client.rpc('set_app_secret',
          params: {'p_key': 'gemini_api_key', 'p_value': 'abc123'})).called(1);
    });
  });

  group('clearGeminiKey', () {
    test('returns NetworkFailure when offline', () async {
      when(() => connectivity.state).thenReturn(_offline);

      final result = await repo.clearGeminiKey();

      expect(result, const Left(NetworkFailure('لا يوجد اتصال بالإنترنت')));
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('returns ServerFailure on PostgrestException', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      final result = await repo.clearGeminiKey();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('calls the clear_app_secret RPC', () async {
      when(() => connectivity.state).thenReturn(_online);
      rpcThrows();

      await repo.clearGeminiKey();

      verify(() => client.rpc('clear_app_secret',
          params: {'p_key': 'gemini_api_key'})).called(1);
    });
  });

  group('GeminiKeyStatus.fromJson', () {
    test('parses a set key with masked last4', () {
      final status = GeminiKeyStatus.fromJson({
        'is_set': true,
        'last4': 'wXyZ',
        'updated_at': '2026-10-24T12:00:00Z',
      });
      expect(status.isSet, isTrue);
      expect(status.last4, 'wXyZ');
      expect(status.updatedAt, isNotNull);
    });

    test('parses an unset key', () {
      final status = GeminiKeyStatus.fromJson({
        'is_set': false,
        'last4': null,
        'updated_at': null,
      });
      expect(status.isSet, isFalse);
      expect(status.last4, isNull);
      expect(status.updatedAt, isNull);
    });
  });
}
