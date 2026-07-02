// lib/features/sections/cubit/sections_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/section_repository.dart';
import 'sections_state.dart';

class SectionsCubit extends Cubit<SectionsState> {
  final SectionRepository _repository;

  SectionsCubit(this._repository) : super(const SectionsInitial());

  Future<void> loadSections() async {
    emit(const SectionsLoading());
    final result = await _repository.getSections();
    if (isClosed) return;
    result.fold(
      (failure) => emit(SectionsError(failure.message)),
      (sections) => sections.isEmpty
          ? emit(const SectionsEmpty())
          : emit(SectionsLoaded(sections)),
    );
  }
}
