// lib/features/books/cubit/book_details_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/book_repository.dart';
import 'book_details_state.dart';

class BookDetailsCubit extends Cubit<BookDetailsState> {
  final BookRepository _repo;

  BookDetailsCubit(this._repo) : super(BookDetailsInitial());

  Future<void> loadBook(String bookId) async {
    emit(BookDetailsLoading());

    final bookResult = await _repo.getBookDetails(bookId);
    if (bookResult.isLeft()) {
      final msg = bookResult.fold((f) => f.message, (_) => '');
      emit(BookDetailsError(msg));
      return;
    }
    final book = bookResult.getOrElse(() => throw StateError(''));

    final lessonsResult = await _repo.getLessonsWithProgress(bookId);
    final enrolledResult = await _repo.isEnrolled(bookId);
    final percentResult = await _repo.getCompletionPercentage(bookId);
    final examResult = await _repo.hasFinalExam(bookId);
    final bestAttemptResult = await _repo.getBestExamAttempt(bookId);

    if (lessonsResult.isLeft()) {
      final msg = lessonsResult.fold(
          (f) => f.message, (_) => 'حدث خطأ أثناء تحميل الدروس');
      emit(BookDetailsError(msg));
      return;
    }

    emit(BookDetailsLoaded(
      book: book,
      lessons: lessonsResult.getOrElse(() => const []),
      isEnrolled: enrolledResult.getOrElse(() => false),
      completionPercentage: percentResult.getOrElse(() => 0.0),
      hasFinalExam: examResult.getOrElse(() => false),
      bestExamAttempt: bestAttemptResult.getOrElse(() => null),
    ));
  }

  Future<void> enroll(String bookId) async {
    final current = state;
    if (current is! BookDetailsLoaded) return;

    emit(current.copyWith(isEnrolling: true));

    final result = await _repo.enrollInBook(bookId);
    result.fold(
      (failure) => emit(current.copyWith(isEnrolling: false)),
      (_) async {
        final lessonsResult = await _repo.getLessonsWithProgress(bookId);
        emit(current.copyWith(
          isEnrolled: true,
          isEnrolling: false,
          lessons: lessonsResult.getOrElse(() => current.lessons),
        ));
      },
    );
  }

  Future<void> refreshProgress(String bookId) async {
    final current = state;
    if (current is! BookDetailsLoaded) return;

    final lessonsResult = await _repo.getLessonsWithProgress(bookId);
    final percentResult = await _repo.getCompletionPercentage(bookId);

    final lessons = lessonsResult.fold(
      (_) => current.lessons,
      (l) => l,
    );
    final pct = percentResult.fold(
      (_) => current.completionPercentage,
      (p) => p,
    );

    emit(current.copyWith(lessons: lessons, completionPercentage: pct));
  }
}
