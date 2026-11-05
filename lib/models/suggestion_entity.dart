// lib/models/suggestion_entity.dart
import 'package:equatable/equatable.dart';

import '../core/utils/media_duration.dart';

/// The kind of media a suggestion points to.
/// - [video] → YouTube link, played in-app via the shared VideoTab player.
/// - [audio] → Google Drive link, played via the shared download-then-play flow.
enum SuggestionContentType {
  video,
  audio;

  static SuggestionContentType fromValue(String value) {
    return SuggestionContentType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => SuggestionContentType.video,
    );
  }

  String get value => name;
}

/// A curated "مقترحات" media card shown in the Home slider and managed by admin.
/// Mirrors the banners data shape; backed by the `suggestions` table (0017).
class SuggestionEntity extends Equatable {
  final String id;
  final String title;
  final String imageUrl;
  final SuggestionContentType contentType;
  final String contentUrl;
  final int durationSeconds;

  /// Nullable: NULLs are ordered LAST by the fetch query (nullsFirst: false).
  final int? sortOrder;
  final bool isActive;

  const SuggestionEntity({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.contentType,
    required this.contentUrl,
    required this.durationSeconds,
    this.sortOrder,
    required this.isActive,
  });

  bool get isVideo => contentType == SuggestionContentType.video;
  bool get isAudio => contentType == SuggestionContentType.audio;

  /// `mm:ss` (< 1h) or `hh:mm:ss` (≥ 1h), RTL-safe. Reuses the shared formatter.
  String get formattedDuration =>
      formatNoteTimestamp(Duration(seconds: durationSeconds));

  factory SuggestionEntity.fromJson(Map<String, dynamic> json) {
    return SuggestionEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String,
      contentType: SuggestionContentType.fromValue(
        json['content_type'] as String,
      ),
      contentUrl: json['content_url'] as String,
      durationSeconds: json['duration_seconds'] as int,
      sortOrder: json['sort_order'] as int?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'image_url': imageUrl,
      'content_type': contentType.value,
      'content_url': contentUrl,
      'duration_seconds': durationSeconds,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    imageUrl,
    contentType,
    contentUrl,
    durationSeconds,
    sortOrder,
    isActive,
  ];
}
