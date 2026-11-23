// lib/features/admin/levels/cubit/admin_levels_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/level_entity.dart';

abstract class AdminLevelsState extends Equatable {
  const AdminLevelsState();
  @override
  List<Object?> get props => [];
}

class AdminLevelsInitial extends AdminLevelsState {}

class AdminLevelsLoading extends AdminLevelsState {}

/// The loaded list. Carries optional one-shot feedback for list mutations
/// (delete / reorder) that must not blank the list — mirrors the loading-quotes
/// pattern. Nonces make an identical message re-trigger the SnackBar.
class AdminLevelsLoaded extends AdminLevelsState {
  final List<LevelEntity> levels;
  final String? transientSuccess;
  final int successNonce;
  final String? transientError;
  final int errorNonce;

  const AdminLevelsLoaded(
    this.levels, {
    this.transientSuccess,
    this.successNonce = 0,
    this.transientError,
    this.errorNonce = 0,
  });

  @override
  List<Object?> get props => [
    levels,
    transientSuccess,
    successNonce,
    transientError,
    errorNonce,
  ];
}

/// Full-screen load failure (also drives the form page's error SnackBar, where
/// the list builder is never rendered — mirrors AdminSectionsError).
class AdminLevelsError extends AdminLevelsState {
  final String message;
  const AdminLevelsError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Emitted after a successful create/edit so the form page can pop + refresh.
class AdminLevelMutationSuccess extends AdminLevelsState {}
