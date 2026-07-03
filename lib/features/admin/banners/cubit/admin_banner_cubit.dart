// lib/features/admin/banners/cubit/admin_banner_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_banner_repository.dart';
import 'admin_banner_state.dart';

class AdminBannerCubit extends Cubit<AdminBannerState> {
  final AdminBannerRepository _repo;

  AdminBannerCubit(this._repo) : super(AdminBannerInitial());

  Future<void> load() async {
    emit(AdminBannerLoading());

    final bannersResult = await _repo.getBanners();
    final booksResult = await _repo.getPublishedBooks();

    final failure = bannersResult.fold((f) => f, (_) => null) ??
        booksResult.fold((f) => f, (_) => null);

    if (failure != null) {
      emit(AdminBannerError(failure.message));
      return;
    }

    emit(AdminBannerLoaded(
      banners: bannersResult.getOrElse(() => []),
      books: booksResult.getOrElse(() => []),
    ));
  }

  Future<String?> uploadImageAndGetUrl(String localPath) async {
    final result = await _repo.uploadBannerImage(localPath);
    return result.fold((f) {
      emit(AdminBannerError(f.message));
      return null;
    }, (url) => url);
  }

  Future<void> createBanner({
    required String title,
    String? description,
    String? imageUrl,
    String? linkedBookId,
    String? externalLink,
    required int orderIndex,
    required bool isActive,
  }) async {
    final result = await _repo.createBanner(
      title: title,
      description: description,
      imageUrl: imageUrl,
      linkedBookId: linkedBookId,
      externalLink: externalLink,
      orderIndex: orderIndex,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminBannerError(f.message)),
      (_) => emit(AdminBannerMutationSuccess()),
    );
  }

  Future<void> updateBanner({
    required String id,
    required String title,
    String? description,
    String? imageUrl,
    String? linkedBookId,
    String? externalLink,
    required int orderIndex,
    required bool isActive,
  }) async {
    final result = await _repo.updateBanner(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      linkedBookId: linkedBookId,
      externalLink: externalLink,
      orderIndex: orderIndex,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminBannerError(f.message)),
      (_) => emit(AdminBannerMutationSuccess()),
    );
  }

  Future<void> deleteBanner(String id) async {
    final result = await _repo.deleteBanner(id);
    result.fold(
      (f) => emit(AdminBannerError(f.message)),
      (_) => load(),
    );
  }
}
