// lib/features/auth/pending_conversion.dart
import 'package:shared_preferences/shared_preferences.dart';

/// A guest→registered conversion's "finish the journey" intent: enroll in the
/// gated book and return to where the guest was blocked.
///
/// Persisted (not held in memory) on purpose: creating the account is a durable
/// server-side effect, so the pending enroll+return must be equally durable.
/// That way a signup page disposed mid-conversion — or the app being killed
/// before the enroll completes — is recoverable on the next launch instead of
/// leaving a registered-but-unenrolled orphan. Consumed by the app-level auth
/// listener (see app.dart). A short TTL prevents yanking the user to a
/// long-abandoned destination on a much-later launch.
class PendingConversion {
  const PendingConversion({this.returnTo, this.autoEnrollBookId});

  final String? returnTo;
  final String? autoEnrollBookId;

  static const _kReturnTo = 'pending_conv_return_to';
  static const _kBookId = 'pending_conv_book_id';
  static const _kSavedAt = 'pending_conv_saved_at';
  static const _ttl = Duration(minutes: 10);

  bool get isEmpty =>
      (returnTo == null || returnTo!.isEmpty) &&
      (autoEnrollBookId == null || autoEnrollBookId!.isEmpty);

  /// Persists the intent just before a conversion / collision sign-in starts.
  /// No-op when there is nothing to carry.
  static Future<void> save({
    String? returnTo,
    String? autoEnrollBookId,
  }) async {
    if (PendingConversion(
      returnTo: returnTo,
      autoEnrollBookId: autoEnrollBookId,
    ).isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (returnTo != null && returnTo.isNotEmpty) {
      await prefs.setString(_kReturnTo, returnTo);
    } else {
      await prefs.remove(_kReturnTo);
    }
    if (autoEnrollBookId != null && autoEnrollBookId.isNotEmpty) {
      await prefs.setString(_kBookId, autoEnrollBookId);
    } else {
      await prefs.remove(_kBookId);
    }
    await prefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// The pending intent, or null if none / stale. A stale intent is cleared.
  static Future<PendingConversion?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getInt(_kSavedAt);
    final returnTo = prefs.getString(_kReturnTo);
    final bookId = prefs.getString(_kBookId);
    if (savedAt == null && returnTo == null && bookId == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - (savedAt ?? 0);
    if (age > _ttl.inMilliseconds) {
      await clear();
      return null;
    }
    return PendingConversion(returnTo: returnTo, autoEnrollBookId: bookId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kReturnTo);
    await prefs.remove(_kBookId);
    await prefs.remove(_kSavedAt);
  }
}
