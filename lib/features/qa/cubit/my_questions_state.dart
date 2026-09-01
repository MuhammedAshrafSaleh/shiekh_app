// lib/features/qa/cubit/my_questions_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/student_question_entity.dart';

abstract class MyQuestionsState extends Equatable {
  const MyQuestionsState();
  @override
  List<Object?> get props => [];
}

class MyQuestionsInitial extends MyQuestionsState {}

class MyQuestionsLoading extends MyQuestionsState {}

class MyQuestionsLoaded extends MyQuestionsState {
  final List<StudentQuestionEntity> questions;
  const MyQuestionsLoaded(this.questions);
  @override
  List<Object?> get props => [questions];
}

class MyQuestionsEmpty extends MyQuestionsState {}

class MyQuestionsError extends MyQuestionsState {
  final String message;
  const MyQuestionsError(this.message);
  @override
  List<Object?> get props => [message];
}
