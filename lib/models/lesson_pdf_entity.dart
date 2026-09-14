// lib/models/lesson_pdf_entity.dart
import 'package:equatable/equatable.dart';

/// A single titled PDF attached to a lesson (migration 0012_lesson_pdfs).
/// A lesson can carry several of these, ordered by [orderIndex].
class LessonPdfEntity extends Equatable {
  final String id;
  final String lessonId;
  final String title;
  final String url;
  final int orderIndex;

  const LessonPdfEntity({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.url,
    required this.orderIndex,
  });

  /// Tolerant of PARTIAL embeds: the admin lesson-list fetch selects only
  /// `lesson_pdfs(id)` (to derive `hasPdf` from the list length in a single
  /// parsing branch), so every field except `id` may be absent. Full-row embeds
  /// (`lesson_pdfs(*)`) populate everything.
  factory LessonPdfEntity.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String? ?? '';
    // A full-row embed that carries the 'url' key should never parse it empty —
    // that signals a bad DB row. Partial embeds (admin list: only 'id') omit the
    // key entirely and are exempt. Debug-only; stripped in release.
    assert(
      !json.containsKey('url') || url.isNotEmpty,
      'LessonPdfEntity.fromJson: "url" present but empty for id=${json['id']}',
    );
    return LessonPdfEntity(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: url,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  LessonPdfEntity copyWith({
    String? title,
    String? url,
    int? orderIndex,
  }) {
    return LessonPdfEntity(
      id: id,
      lessonId: lessonId,
      title: title ?? this.title,
      url: url ?? this.url,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  List<Object?> get props => [id, lessonId, title, url, orderIndex];
}
