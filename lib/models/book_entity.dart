// lib/models/book_entity.dart
import 'package:equatable/equatable.dart';

// Sentinel so copyWith callers can explicitly pass null to clear a nullable field.
const _clear = Object();

class BookEntity extends Equatable {
  final String id;
  final String sectionId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String status; // 'draft' | 'published'
  final String reviewStatus; // 'in_review' | 'completed'
  final bool isFeatured;
  final int? featuredOrder;
  final String? levelId;
  final int? levelOrder;

  const BookEntity({
    required this.id,
    required this.sectionId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.status,
    this.reviewStatus = 'in_review',
    required this.isFeatured,
    this.featuredOrder,
    this.levelId,
    this.levelOrder,
  });

  factory BookEntity.fromJson(Map<String, dynamic> json) {
    return BookEntity(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String,
      reviewStatus: json['review_status'] as String? ?? 'in_review',
      isFeatured: json['is_featured'] as bool,
      featuredOrder: json['featured_order'] as int?,
      levelId: json['level_id'] as String?,
      levelOrder: json['level_order'] as int?,
    );
  }

  // Pass `clearLevelId: true` / `clearLevelOrder: true` to explicitly null these out.
  // All other nullable fields follow the same ?-then-keep pattern as the original entity.
  BookEntity copyWith({
    String? sectionId,
    String? title,
    String? description,
    String? coverImageUrl,
    String? status,
    String? reviewStatus,
    bool? isFeatured,
    int? featuredOrder,
    Object? levelId = _clear,
    Object? levelOrder = _clear,
  }) {
    return BookEntity(
      id: id,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredOrder: featuredOrder ?? this.featuredOrder,
      levelId: identical(levelId, _clear) ? this.levelId : levelId as String?,
      levelOrder: identical(levelOrder, _clear) ? this.levelOrder : levelOrder as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sectionId,
    title,
    description,
    coverImageUrl,
    status,
    reviewStatus,
    isFeatured,
    featuredOrder,
    levelId,
    levelOrder,
  ];
}
