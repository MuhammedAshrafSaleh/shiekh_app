// lib/models/book_entity.dart
import 'package:equatable/equatable.dart';

class BookEntity extends Equatable {
  final String id;
  final String sectionId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String status;
  final bool isFeatured;
  final int? featuredOrder;

  const BookEntity({
    required this.id,
    required this.sectionId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.status,
    required this.isFeatured,
    this.featuredOrder,
  });

  factory BookEntity.fromJson(Map<String, dynamic> json) {
    return BookEntity(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String,
      isFeatured: json['is_featured'] as bool,
      featuredOrder: json['featured_order'] as int?,
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
        isFeatured,
        featuredOrder,
      ];
}
