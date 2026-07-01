// lib/core/utils/drive_url.dart
final _idPattern = RegExp(r'/d/([^/]+)');

String toDirectDownloadUrl(String driveShareUrl) {
  final match = _idPattern.firstMatch(driveShareUrl);
  if (match == null) return driveShareUrl;
  final id = match.group(1)!;
  return 'https://drive.google.com/uc?export=download&id=$id';
}
