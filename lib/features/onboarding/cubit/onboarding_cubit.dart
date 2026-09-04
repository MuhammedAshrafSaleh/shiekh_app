// lib/features/onboarding/cubit/onboarding_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingCubit(this._repository) : super(OnboardingInitial());

  Future<void> loadSlides() async {
    emit(OnboardingLoading());
    final result = await _repository.getSlides();
    result.fold(
      (failure) => emit(OnboardingError(failure.message)),
      (slides) => emit(OnboardingLoaded(slides)),
    );
  }
}
