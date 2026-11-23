// lib/models/assignable_book_entity.dart
import 'package:equatable/equatable.dart';

/// A book shown in the "add book to level" picker: its identity plus its
/// CURRENT level (if any), so the UI can add a free book directly or offer to
/// MOVE a book that already belongs to another level. Projection over
/// `books` joined to `levels(name)` — not a full [BookEntity].
class AssignableBookEntity extends Equatable {
  final String id;
  final String title;
  final String? coverImageUrl;
  final String? currentLevelId;
  final String? currentLevelName;

  const AssignableBookEntity({
    required this.id,
    required this.title,
    this.coverImageUrl,
    this.currentLevelId,
    this.currentLevelName,
  });

  bool get hasLevel => currentLevelId != null;

  factory AssignableBookEntity.fromJson(Map<String, dynamic> json) {
    final level = json['levels'] as Map<String, dynamic>?;
    return AssignableBookEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      currentLevelId: json['level_id'] as String?,
      currentLevelName: level?['name'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    coverImageUrl,
    currentLevelId,
    currentLevelName,
  ];
}
