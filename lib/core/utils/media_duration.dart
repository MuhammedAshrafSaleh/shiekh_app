// lib/core/utils/media_duration.dart

/// U+200E Left-to-Right Mark. Built from its code point so the source stays
/// free of invisible literals (which are fragile across edits/copy-paste).
final String _ltrMark = String.fromCharCode(0x200E);

/// Formats a media [Duration] as `mm:ss`.
///
/// Minutes are the *total* minutes (they do not wrap at 60), so a 90-minute
/// duration reads `90:00`, not `30:00`. This matches the exam timer's original
/// behaviour and avoids truncating long audio.
///
/// Guarded against RTL bidi digit-group reversal: in an RTL (Arabic) paragraph
/// the bidi algorithm can flip the two number runs around the `:` separator,
/// rendering `59:07` as `07:59`. Prefixing the [_ltrMark] pins the run to LTR.
/// Render inside a `Text` with `textDirection: TextDirection.ltr` as
/// defense-in-depth.
String formatMediaDuration(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$_ltrMark$m:$s';
}

/// Formats a note timestamp as `mm:ss` (< 1 hour) or `hh:mm:ss` (≥ 1 hour).
///
/// Render inside a `Text` with `textDirection: TextDirection.ltr` as
/// defense-in-depth against RTL bidi reversal.
String formatNoteTimestamp(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = totalSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) {
    return '$_ltrMark${h.toString().padLeft(2, '0')}:$m:$s';
  }
  return '$_ltrMark$m:$s';
}
