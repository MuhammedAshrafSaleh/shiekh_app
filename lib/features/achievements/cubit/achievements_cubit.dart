// lib/features/achievements/cubit/achievements_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/achievements_repository.dart';
import 'achievements_state.dart';

class AchievementsCubit extends Cubit<AchievementsState> {
  final AchievementsRepository _repo;

  AchievementsCubit(this._repo) : super(AchievementsInitial());

  Future<void> loadAchievements() async {
    emit(AchievementsLoading());

    final dataResult = await _repo.getAchievementsData();
    if (dataResult.isLeft()) {
      emit(AchievementsError(dataResult.fold((f) => f.message, (_) => '')));
      return;
    }

    final certsResult = await _repo.getCertificates();
    if (certsResult.isLeft()) {
      emit(AchievementsError(certsResult.fold((f) => f.message, (_) => '')));
      return;
    }

    emit(
      AchievementsLoaded(
        data: dataResult.getOrElse(() => throw StateError('')),
        certificates: certsResult.getOrElse(() => []),
      ),
    );
  }
}
