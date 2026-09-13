// lib/features/admin/lessons/cubit/generate_questions_state.dart
import 'package:equatable/equatable.dart';

abstract class GenerateQuestionsState extends Equatable {
  const GenerateQuestionsState();
  @override
  List<Object?> get props => [];
}

class GenerateQuestionsInitial extends GenerateQuestionsState {}

/// Long-running generation in progress (30–130+ s). Drives the "may take a
/// minute or more" loading UI.
class GenerateQuestionsGenerating extends GenerateQuestionsState {}

class GenerateQuestionsSuccess extends GenerateQuestionsState {
  final int insertedCount;
  const GenerateQuestionsSuccess(this.insertedCount);
  @override
  List<Object?> get props => [insertedCount];
}

class GenerateQuestionsError extends GenerateQuestionsState {
  final String message;
  const GenerateQuestionsError(this.message);
  @override
  List<Object?> get props => [message];
}
