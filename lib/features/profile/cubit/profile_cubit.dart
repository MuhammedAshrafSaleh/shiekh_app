// lib/features/profile/cubit/profile_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repo;

  ProfileCubit(this._repo) : super(ProfileInitial());

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    final result = await _repo.getProfileStats();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (stats) => emit(ProfileLoaded(stats)),
    );
  }

  Future<bool> updateName(String fullName) async {
    final current = state;
    if (current is! ProfileLoaded) return false;
    emit(ProfileUpdating(current.stats));
    final result = await _repo.updateFullName(fullName);
    return result.fold(
      (failure) {
        emit(ProfileLoaded(current.stats));
        return false;
      },
      (_) {
        emit(ProfileLoaded(ProfileStats(
          fullName: fullName,
          email: current.stats.email,
          enrolledBooks: current.stats.enrolledBooks,
          completedLessons: current.stats.completedLessons,
          certificates: current.stats.certificates,
        )));
        return true;
      },
    );
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state;
    if (current is! ProfileLoaded) return false;
    emit(ProfileUpdating(current.stats));
    final result = await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return result.fold(
      (failure) {
        emit(ProfileLoaded(current.stats));
        return false;
      },
      (_) {
        emit(ProfileLoaded(current.stats));
        return true;
      },
    );
  }
}
