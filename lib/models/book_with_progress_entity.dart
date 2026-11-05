// lib/models/book_with_progress_entity.dart
import 'package:equatable/equatable.dart';

import 'book_entity.dart';

class BookWithProgressEntity extends Equatable {
  final BookEntity book;
  final double progress;
  final bool isEnrolled;
  final int totalLessons;
  final int completedLessons;

  const BookWithProgressEntity({
    required this.book,
    required this.progress,
    required this.isEnrolled,
    required this.totalLessons,
    required this.completedLessons,
  });

  @override
  List<Object?> get props => [
    book,
    progress,
    isEnrolled,
    totalLessons,
    completedLessons,
  ];
}
