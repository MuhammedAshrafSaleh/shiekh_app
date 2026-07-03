// lib/features/admin/qa/cubit/admin_qa_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/student_question_entity.dart';

abstract class AdminQaState extends Equatable {
  const AdminQaState();
  @override
  List<Object?> get props => [];
}

class AdminQaInitial extends AdminQaState {}

class AdminQaLoading extends AdminQaState {}

class AdminQaLoaded extends AdminQaState {
  final List<StudentQuestionEntity> pending;
  final List<StudentQuestionEntity> answered;

  const AdminQaLoaded({required this.pending, required this.answered});

  @override
  List<Object?> get props => [pending, answered];
}

class AdminQaError extends AdminQaState {
  final String message;
  const AdminQaError(this.message);
  @override
  List<Object?> get props => [message];
}
