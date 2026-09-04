// lib/features/onboarding/cubit/onboarding_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/onboarding_slide_entity.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();
  @override
  List<Object?> get props => [];
}

class OnboardingInitial extends OnboardingState {}

class OnboardingLoading extends OnboardingState {}

class OnboardingLoaded extends OnboardingState {
  final List<OnboardingSlideEntity> slides;
  const OnboardingLoaded(this.slides);
  @override
  List<Object?> get props => [slides];
}

class OnboardingError extends OnboardingState {
  final String message;
  const OnboardingError(this.message);
  @override
  List<Object?> get props => [message];
}
