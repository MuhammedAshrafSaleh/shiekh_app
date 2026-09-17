// lib/models/lesson_note_entity.dart
import 'package:equatable/equatable.dart';

class LessonNoteEntity extends Equatable {
  final String id;
  final String userId;
  final String lessonId;
  final String bookId;
  final String noteText;
  final int positionSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonNoteEntity({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.bookId,
    required this.noteText,
    required this.positionSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonNoteEntity.fromJson(Map<String, dynamic> json) {
    return LessonNoteEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      bookId: json['book_id'] as String,
      noteText: json['note_text'] as String,
      positionSeconds: json['position_seconds'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  LessonNoteEntity copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? bookId,
    String? noteText,
    int? positionSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonNoteEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      bookId: bookId ?? this.bookId,
      noteText: noteText ?? this.noteText,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    lessonId,
    bookId,
    noteText,
    positionSeconds,
    createdAt,
    updatedAt,
  ];
}
