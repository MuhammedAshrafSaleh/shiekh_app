// lib/features/books/cubit/book_details_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/book_entity.dart';
import '../../../models/final_exam_attempt_entity.dart';
import '../../../models/lesson_with_progress_entity.dart';

abstract class BookDetailsState extends Equatable {
  const BookDetailsState();
  @override
  List<Object?> get props => [];
}

class BookDetailsInitial extends BookDetailsState {}

class BookDetailsLoading extends BookDetailsState {}

class BookDetailsLoaded extends BookDetailsState {
  final BookEntity book;
  final List<LessonWithProgressEntity> lessons;
  final bool isEnrolled;
  final double completionPercentage;
  final bool hasFinalExam;
  final bool isEnrolling;
  final FinalExamAttemptEntity? bestExamAttempt;

  const BookDetailsLoaded({
    required this.book,
    required this.lessons,
    required this.isEnrolled,
    required this.completionPercentage,
    required this.hasFinalExam,
    this.isEnrolling = false,
    this.bestExamAttempt,
  });

  BookDetailsLoaded copyWith({
    bool? isEnrolled,
    double? completionPercentage,
    List<LessonWithProgressEntity>? lessons,
    bool? isEnrolling,
    FinalExamAttemptEntity? bestExamAttempt,
  }) {
    return BookDetailsLoaded(
      book: book,
      lessons: lessons ?? this.lessons,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      hasFinalExam: hasFinalExam,
      isEnrolling: isEnrolling ?? this.isEnrolling,
      bestExamAttempt: bestExamAttempt ?? this.bestExamAttempt,
    );
  }

  @override
  List<Object?> get props => [
    book,
    lessons,
    isEnrolled,
    completionPercentage,
    hasFinalExam,
    isEnrolling,
    bestExamAttempt,
  ];
}

class BookDetailsError extends BookDetailsState {
  final String message;
  const BookDetailsError(this.message);
  @override
  List<Object?> get props => [message];
}
