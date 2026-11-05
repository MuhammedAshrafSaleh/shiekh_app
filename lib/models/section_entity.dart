// lib/models/section_entity.dart
import 'package:equatable/equatable.dart';

class SectionEntity extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String? description;
  final int bookCount;

  const SectionEntity({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
    required this.bookCount,
  });

  factory SectionEntity.fromJson(
    Map<String, dynamic> json, {
    int bookCount = 0,
  }) {
    return SectionEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      description: json['description'] as String?,
      bookCount: bookCount,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, description, bookCount];
}
