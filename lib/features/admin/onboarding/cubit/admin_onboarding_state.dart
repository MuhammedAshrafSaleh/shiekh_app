// lib/features/admin/onboarding/cubit/admin_onboarding_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/onboarding_slide_entity.dart';

abstract class AdminOnboardingState extends Equatable {
  const AdminOnboardingState();
  @override
  List<Object?> get props => [];
}

class AdminOnboardingInitial extends AdminOnboardingState {}

class AdminOnboardingLoading extends AdminOnboardingState {}

class AdminOnboardingLoaded extends AdminOnboardingState {
  final List<OnboardingSlideEntity> slides;
  const AdminOnboardingLoaded(this.slides);
  @override
  List<Object?> get props => [slides];
}

class AdminOnboardingError extends AdminOnboardingState {
  final String message;
  const AdminOnboardingError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Transient signal for a green success SnackBar. Carries a fresh id so two
/// successive identical messages still notify the listener.
class AdminOnboardingActionSuccess extends AdminOnboardingState {
  final String message;
  final int nonce;
  const AdminOnboardingActionSuccess(this.message, this.nonce);
  @override
  List<Object?> get props => [message, nonce];
}
