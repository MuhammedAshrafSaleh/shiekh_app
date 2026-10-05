// lib/models/loading_quote_entity.dart
import 'package:equatable/equatable.dart';

/// A motivational text shown on the practice-exam loading screen. Managed from
/// the admin panel (table `loading_quotes`); falls back to seeded defaults.
class LoadingQuoteEntity extends Equatable {
  final String id;
  final String text;
  final String? source;
  final int sortOrder;
  final bool isActive;

  const LoadingQuoteEntity({
    required this.id,
    required this.text,
    required this.source,
    required this.sortOrder,
    required this.isActive,
  });

  factory LoadingQuoteEntity.fromJson(Map<String, dynamic> json) {
    return LoadingQuoteEntity(
      id: json['id'] as String,
      text: json['text'] as String,
      source: json['source'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  LoadingQuoteEntity copyWith({int? sortOrder, bool? isActive}) {
    return LoadingQuoteEntity(
      id: id,
      text: text,
      source: source,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, text, source, sortOrder, isActive];
}
