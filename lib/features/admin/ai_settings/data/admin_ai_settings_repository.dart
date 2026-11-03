// lib/features/admin/ai_settings/data/admin_ai_settings_repository.dart
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/notifications/cubit/connectivity_cubit.dart';

/// Masked status of the stored Gemini API key. Never carries the full key —
/// the raw value lives server-side only (see migration 0022_app_secrets.sql).
class GeminiKeyStatus extends Equatable {
  final bool isSet;
  final String? last4;
  final DateTime? updatedAt;

  const GeminiKeyStatus({required this.isSet, this.last4, this.updatedAt});

  factory GeminiKeyStatus.fromJson(Map<String, dynamic> json) =>
      GeminiKeyStatus(
        isSet: json['is_set'] == true,
        last4: json['last4'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'] as String),
      );

  @override
  List<Object?> get props => [isSet, last4, updatedAt];
}

/// Admin management of the AI (Gemini) API key used by the generation/
/// transcription Edge Functions. All access goes through SECURITY DEFINER RPCs
/// (`get_secret_status` / `set_app_secret` / `clear_app_secret`) — the client
/// never reads or writes the `app_secrets` table directly. Postgres errors are
/// mapped to Arabic — never surfaced raw.
class AdminAiSettingsRepository {
  final SupabaseClient _client;
  final ConnectivityCubit _connectivity;
  final _log = Logger('AdminAiSettingsRepository');

  static const _geminiKey = 'gemini_api_key';

  AdminAiSettingsRepository(this._client, this._connectivity);

  Either<Failure, T>? _checkNetwork<T>() {
    if (!_connectivity.state.isOffline) return null;
    return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
  }

  Future<Either<Failure, GeminiKeyStatus>> getGeminiKeyStatus() async {
    final net = _checkNetwork<GeminiKeyStatus>();
    if (net != null) return net;
    try {
      final data = await _client.rpc(
        'get_secret_status',
        params: {'p_key': _geminiKey},
      );
      return Right(
        GeminiKeyStatus.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on PostgrestException catch (e) {
      _log.warning('getGeminiKeyStatus: ${e.message}');
      return Left(ServerFailure('تعذّر تحميل حالة المفتاح، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> setGeminiKey(String key) async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.rpc(
        'set_app_secret',
        params: {'p_key': _geminiKey, 'p_value': key.trim()},
      );
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('setGeminiKey: ${e.message}');
      return Left(ServerFailure('تعذّر حفظ المفتاح، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }

  Future<Either<Failure, Unit>> clearGeminiKey() async {
    final net = _checkNetwork<Unit>();
    if (net != null) return net;
    try {
      await _client.rpc('clear_app_secret', params: {'p_key': _geminiKey});
      return const Right(unit);
    } on PostgrestException catch (e) {
      _log.warning('clearGeminiKey: ${e.message}');
      return Left(ServerFailure('تعذّر حذف المفتاح، حاول مرة أخرى.'));
    } on SocketException {
      return Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }
  }
}
