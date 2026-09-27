// lib/features/admin/suggestions/cubit/admin_suggestion_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/suggestion_entity.dart';

abstract class AdminSuggestionState extends Equatable {
  const AdminSuggestionState();
  @override
  List<Object?> get props => [];
}

class AdminSuggestionInitial extends AdminSuggestionState {}

class AdminSuggestionLoading extends AdminSuggestionState {}

class AdminSuggestionLoaded extends AdminSuggestionState {
  final List<SuggestionEntity> suggestions;
  const AdminSuggestionLoaded({required this.suggestions});
  @override
  List<Object?> get props => [suggestions];
}

class AdminSuggestionError extends AdminSuggestionState {
  final String message;
  const AdminSuggestionError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminSuggestionMutationSuccess extends AdminSuggestionState {}
