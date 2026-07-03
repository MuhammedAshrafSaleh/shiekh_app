// lib/features/profile/cubit/profile_state.dart
import 'package:equatable/equatable.dart';

import '../data/profile_repository.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileStats stats;
  const ProfileLoaded(this.stats);

  @override
  List<Object?> get props => [stats.fullName, stats.email];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

// Separate states for in-progress mutations so the UI can show feedback
class ProfileUpdating extends ProfileLoaded {
  const ProfileUpdating(super.stats);
}
