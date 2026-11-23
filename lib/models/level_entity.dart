// lib/models/level_entity.dart
import 'package:equatable/equatable.dart';

/// Academic level / year (e.g. "السنة التمهيدية"). Admin-managed, cross-cutting
/// grouping of books independent of sections. `bookCount` is computed at load
/// time (not a stored column), mirroring [SectionEntity].
class LevelEntity extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final int bookCount;

  const LevelEntity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.bookCount,
  });

  factory LevelEntity.fromJson(Map<String, dynamic> json, {int bookCount = 0}) {
    return LevelEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      bookCount: bookCount,
    );
  }

  LevelEntity copyWith({String? name, int? sortOrder, int? bookCount}) {
    return LevelEntity(
      id: id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      bookCount: bookCount ?? this.bookCount,
    );
  }

  @override
  List<Object?> get props => [id, name, sortOrder, bookCount];
}
