// lib/features/home/cubit/home_cubit.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../../../core/errors/failures.dart';
import '../../../models/banner_entity.dart';
import '../../../models/book_with_progress_entity.dart';
import '../../../models/suggestion_entity.dart';
import '../data/home_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;
  final _log = Logger('HomeCubit');

  HomeCubit(this._repository) : super(const HomeInitial());

  Future<void> loadHome() async {
    emit(const HomeLoading());

    final results = await Future.wait([
      _repository.getActiveBanners(),
      _repository.getFeaturedBooks(),
      _repository.getActiveSuggestions(),
    ]);

    if (isClosed) return;

    final bannersEither =
        results[0] as Either<Failure, List<BannerEntity>>;
    final featuredEither =
        results[1] as Either<Failure, List<BookWithProgressEntity>>;
    final suggestionsEither =
        results[2] as Either<Failure, List<SuggestionEntity>>;

    String? errorMessage;

    bannersEither.fold(
      (failure) => errorMessage = failure.message,
      (_) {},
    );

    if (errorMessage != null) {
      emit(HomeError(errorMessage!));
      return;
    }

    featuredEither.fold(
      (failure) => errorMessage = failure.message,
      (_) {},
    );

    if (errorMessage != null) {
      emit(HomeError(errorMessage!));
      return;
    }

    final banners = bannersEither.getOrElse(() => []);
    final featured = featuredEither.getOrElse(() => []);
    // Suggestions must never fail the Home load: a failure just hides the
    // "مقترحات" section, so we fold any error to an empty list. Log it first so
    // a silent RLS/query issue is visible in dev.
    final suggestions = suggestionsEither.fold(
      (failure) {
        _log.warning('getActiveSuggestions failed (section hidden): '
            '${failure.message}');
        return <SuggestionEntity>[];
      },
      (list) => list,
    );

    if (banners.isEmpty && featured.isEmpty && suggestions.isEmpty) {
      emit(const HomeEmpty());
      return;
    }

    emit(
      HomeLoaded(
        HomeData(
          banners: banners,
          featuredBooks: featured,
          suggestions: suggestions,
        ),
      ),
    );
  }
}
