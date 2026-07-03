// lib/features/qa/cubit/qa_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/student_question_entity.dart';

abstract class QaState extends Equatable {
  const QaState();
  @override
  List<Object?> get props => [];
}

class QaInitial extends QaState {}

class QaLoading extends QaState {}

class QaLoaded extends QaState {
  final List<StudentQuestionEntity> questions;
  const QaLoaded(this.questions);
  @override
  List<Object?> get props => [questions];
}

class QaEmpty extends QaState {}

class QaError extends QaState {
  final String message;
  const QaError(this.message);
  @override
  List<Object?> get props => [message];
}

// Separate state for ask-question action (used within the bottom sheet)
abstract class AskQuestionState extends Equatable {
  const AskQuestionState();
  @override
  List<Object?> get props => [];
}

class AskQuestionIdle extends AskQuestionState {}

class AskQuestionSubmitting extends AskQuestionState {}

class AskQuestionSubmitted extends AskQuestionState {}

class AskQuestionError extends AskQuestionState {
  final String message;
  const AskQuestionError(this.message);
  @override
  List<Object?> get props => [message];
}
