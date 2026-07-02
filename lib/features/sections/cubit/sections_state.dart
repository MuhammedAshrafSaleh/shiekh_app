// lib/features/sections/cubit/sections_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/section_entity.dart';

abstract class SectionsState extends Equatable {
  const SectionsState();

  @override
  List<Object?> get props => [];
}

class SectionsInitial extends SectionsState {
  const SectionsInitial();
}

class SectionsLoading extends SectionsState {
  const SectionsLoading();
}

class SectionsLoaded extends SectionsState {
  final List<SectionEntity> sections;
  const SectionsLoaded(this.sections);

  @override
  List<Object?> get props => [sections];
}

class SectionsEmpty extends SectionsState {
  const SectionsEmpty();
}

class SectionsError extends SectionsState {
  final String message;
  const SectionsError(this.message);

  @override
  List<Object?> get props => [message];
}
