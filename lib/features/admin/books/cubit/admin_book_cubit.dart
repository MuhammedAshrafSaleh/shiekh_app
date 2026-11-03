// lib/features/admin/books/cubit/admin_book_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_book_repository.dart';
import 'admin_book_state.dart';

class AdminBookCubit extends Cubit<AdminBookState> {
  final AdminBookRepository _repo;

  AdminBookCubit(this._repo) : super(AdminBookInitial());

  Future<void> loadForm({String? bookId}) async {
    emit(AdminBookLoading());

    final sectionsResult = await _repo.getSections();
    if (sectionsResult.isLeft()) {
      emit(AdminBookError(sectionsResult.fold((f) => f.message, (_) => '')));
      return;
    }
    final sections = sectionsResult.getOrElse(() => []);

    final featuredResult = await _repo.getFeaturedCount(excludeId: bookId);
    final featuredCount = featuredResult.getOrElse(() => 0);

    if (bookId != null) {
      final bookResult = await _repo.getBook(bookId);
      bookResult.fold(
        (f) => emit(AdminBookError(f.message)),
        (book) => emit(
          AdminBookFormReady(
            sections: sections,
            existing: book,
            featuredCount: featuredCount,
          ),
        ),
      );
    } else {
      emit(
        AdminBookFormReady(sections: sections, featuredCount: featuredCount),
      );
    }
  }

  Future<void> uploadCover(String localPath) async {
    final result = await _repo.uploadCoverImage(localPath);
    result.fold((f) => emit(AdminBookError(f.message)), (url) {
      // Re-emit current form with upload signalled via a temp event
      // Caller holds the URL to merge into form state
    });
  }

  Future<String?> uploadCoverAndGetUrl(String localPath) async {
    final result = await _repo.uploadCoverImage(localPath);
    return result.fold((f) {
      emit(AdminBookError(f.message));
      return null;
    }, (url) => url);
  }

  Future<void> save({
    String? bookId,
    required String sectionId,
    required String title,
    String? description,
    String? coverImageUrl,
    required String status,
    required String reviewStatus,
    required bool isFeatured,
    int? featuredOrder,
  }) async {
    emit(AdminBookSaving());
    final result = bookId != null
        ? await _repo.updateBook(
            id: bookId,
            sectionId: sectionId,
            title: title,
            description: description,
            coverImageUrl: coverImageUrl,
            status: status,
            reviewStatus: reviewStatus,
            isFeatured: isFeatured,
            featuredOrder: featuredOrder,
          )
        : await _repo.createBook(
            sectionId: sectionId,
            title: title,
            description: description,
            coverImageUrl: coverImageUrl,
            status: status,
            reviewStatus: reviewStatus,
            isFeatured: isFeatured,
            featuredOrder: featuredOrder,
          );

    result.fold(
      (f) => emit(AdminBookError(f.message)),
      (book) => emit(AdminBookSaveSuccess(book)),
    );
  }
}
