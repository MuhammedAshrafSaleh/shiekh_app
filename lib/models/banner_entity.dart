// lib/models/banner_entity.dart
import 'package:equatable/equatable.dart';

class BannerEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? linkedBookId;
  final String? externalLink;
  final int orderIndex;
  final bool isActive;

  const BannerEntity({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.linkedBookId,
    this.externalLink,
    required this.orderIndex,
    required this.isActive,
  });

  factory BannerEntity.fromJson(Map<String, dynamic> json) {
    return BannerEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      linkedBookId: json['linked_book_id'] as String?,
      externalLink: json['external_link'] as String?,
      orderIndex: json['order_index'] as int,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    imageUrl,
    linkedBookId,
    externalLink,
    orderIndex,
    isActive,
  ];
}
