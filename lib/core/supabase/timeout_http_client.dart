// lib/core/supabase/timeout_http_client.dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A thin [http.Client] wrapper that applies a per-request timeout to every
/// Supabase REST / Auth / Storage call, so a stalled server or a half-open
/// connection can never leave a repository awaiting forever (the infinite
/// loading-spinner class of bug).
///
/// ## Why a client wrapper (not a per-call `.timeout()`)
/// Supabase shares one [http.Client] across its postgrest/auth/storage/functions
/// sub-clients, so wrapping it here covers all ~170 query call-sites in one place
/// with zero repository edits. Realtime uses websockets, not this client, so its
/// own reconnection logic is untouched.
///
/// ## Timeout on expiry → [SocketException] (deliberate)
/// On timeout this throws a [SocketException], NOT a [TimeoutException]. Every
/// repository already has an `on SocketException` handler that maps to
/// `NetworkFailure('لا يوجد اتصال بالإنترنت')`, so a timeout surfaces as a normal,
/// localized network failure with no per-method changes.
///
/// ## Edge Functions are exempt
/// The AI question-generation and transcription Edge Functions legitimately run
/// for well over a minute and set their own call-site timeouts (160s / 170s).
/// Requests to `/functions/` therefore get [functionsTimeout] (a generous outer
/// bound) instead of the short [queryTimeout], so they are never cut off early.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(
    this._inner, {
    this.queryTimeout = const Duration(seconds: 20),
    this.functionsTimeout = const Duration(seconds: 180),
  });

  final http.Client _inner;

  /// Applied to normal REST / Auth / Storage requests.
  final Duration queryTimeout;

  /// Applied to Edge Function invocations (`/functions/` paths), which run long.
  final Duration functionsTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final isFunctionCall = request.url.path.contains('/functions/');
    final limit = isFunctionCall ? functionsTimeout : queryTimeout;
    return _inner.send(request).timeout(
      limit,
      onTimeout: () => throw const SocketException('انتهت مهلة الاتصال بالخادم'),
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
