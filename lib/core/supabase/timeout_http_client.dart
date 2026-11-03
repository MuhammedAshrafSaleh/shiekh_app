// lib/core/supabase/timeout_http_client.dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A thin [http.Client] wrapper that applies a per-request timeout to every
/// Supabase REST / Auth / Storage / Functions call, so a stalled server or a
/// half-open connection can never leave a repository awaiting forever (the
/// infinite loading-spinner class of bug).
///
/// ## Why a client wrapper (not a per-call `.timeout()`)
/// Supabase shares one [http.Client] across its postgrest/auth/storage/functions
/// sub-clients, so wrapping it here covers all query call-sites in one place with
/// zero repository edits. Realtime uses websockets, not this client, so its own
/// reconnection logic is untouched.
///
/// ## Timeout on expiry → [SocketException] (deliberate)
/// On timeout this throws a [SocketException], NOT a [TimeoutException]. Every
/// repository already has an `on SocketException` handler that maps to
/// `NetworkFailure('لا يوجد اتصال بالإنترنت')`, so a timeout surfaces as a normal,
/// localized network failure with no per-method changes.
///
/// ## Edge Functions are no longer special-cased
/// Under the async-queue contract the AI Edge Functions (`transcribe-lesson`,
/// `generate-questions`) just enqueue a job and return HTTP 202 in ~1–2 s — no
/// call is long-running anymore, so the same short [requestTimeout] applies to
/// every request.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(
    this._inner, {
    this.requestTimeout = const Duration(seconds: 20),
  });

  final http.Client _inner;

  /// Applied to every request (REST / Auth / Storage / Functions).
  final Duration requestTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner
        .send(request)
        .timeout(
          requestTimeout,
          onTimeout: () =>
              throw const SocketException('انتهت مهلة الاتصال بالخادم'),
        );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
