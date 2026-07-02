// lib/features/sections/cubit/section_books_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/section_repository.dart';
import 'section_books_state.dart';

class SectionBooksCubit extends Cubit<SectionBooksState> {
  final SectionRepository _repository;

  SectionBooksCubit(this._repository) : super(const SectionBooksInitial());

  Future<void> loadBooks(String sectionId) async {
    emit(const SectionBooksLoading());
    final result = await _repository.getBooksBySection(sectionId: sectionId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(SectionBooksError(failure.message)),
      (books) => books.isEmpty
          ? emit(const SectionBooksEmpty())
          : emit(SectionBooksLoaded(books)),
    );
  }
}
