// lib/core/utils/relative_time.dart
String relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
  if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
  return 'منذ ${(diff.inDays / 365).floor()} سنة';
}
