// lib/features/achievements/cubit/achievements_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/certificate_entity.dart';
import '../data/achievements_repository.dart';

abstract class AchievementsState extends Equatable {
  const AchievementsState();

  @override
  List<Object?> get props => [];
}

class AchievementsInitial extends AchievementsState {}

class AchievementsLoading extends AchievementsState {}

class AchievementsLoaded extends AchievementsState {
  final AchievementsData data;
  final List<CertificateEntity> certificates;

  const AchievementsLoaded({
    required this.data,
    required this.certificates,
  });

  @override
  List<Object?> get props => [data, certificates];
}

class AchievementsError extends AchievementsState {
  final String message;
  const AchievementsError(this.message);

  @override
  List<Object?> get props => [message];
}
