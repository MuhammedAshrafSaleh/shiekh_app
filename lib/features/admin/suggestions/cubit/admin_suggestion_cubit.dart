// lib/features/admin/suggestions/cubit/admin_suggestion_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/suggestion_entity.dart';
import '../data/admin_suggestion_repository.dart';
import 'admin_suggestion_state.dart';

class AdminSuggestionCubit extends Cubit<AdminSuggestionState> {
  final AdminSuggestionRepository _repo;

  AdminSuggestionCubit(this._repo) : super(AdminSuggestionInitial());

  Future<void> load() async {
    emit(AdminSuggestionLoading());
    final result = await _repo.getSuggestions();
    result.fold(
      (f) => emit(AdminSuggestionError(f.message)),
      (suggestions) => emit(AdminSuggestionLoaded(suggestions: suggestions)),
    );
  }

  Future<String?> uploadImageAndGetUrl(String localPath) async {
    final result = await _repo.uploadSuggestionImage(localPath);
    return result.fold((f) {
      emit(AdminSuggestionError(f.message));
      return null;
    }, (url) => url);
  }

  Future<void> createSuggestion({
    required String title,
    required String imageUrl,
    required SuggestionContentType contentType,
    required String contentUrl,
    required int durationSeconds,
    int? sortOrder,
    required bool isActive,
  }) async {
    final result = await _repo.createSuggestion(
      title: title,
      imageUrl: imageUrl,
      contentType: contentType,
      contentUrl: contentUrl,
      durationSeconds: durationSeconds,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminSuggestionError(f.message)),
      (_) => emit(AdminSuggestionMutationSuccess()),
    );
  }

  Future<void> updateSuggestion({
    required String id,
    required String title,
    required String imageUrl,
    required SuggestionContentType contentType,
    required String contentUrl,
    required int durationSeconds,
    int? sortOrder,
    required bool isActive,
  }) async {
    final result = await _repo.updateSuggestion(
      id: id,
      title: title,
      imageUrl: imageUrl,
      contentType: contentType,
      contentUrl: contentUrl,
      durationSeconds: durationSeconds,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminSuggestionError(f.message)),
      (_) => emit(AdminSuggestionMutationSuccess()),
    );
  }

  Future<void> deleteSuggestion(String id) async {
    final result = await _repo.deleteSuggestion(id);
    result.fold((f) => emit(AdminSuggestionError(f.message)), (_) => load());
  }
}
