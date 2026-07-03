// lib/features/admin/exam/cubit/admin_exam_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/admin_final_exam_question_entity.dart';
import '../../../../models/final_exam_settings_entity.dart';

abstract class AdminExamState extends Equatable {
  const AdminExamState();
  @override
  List<Object?> get props => [];
}

class AdminExamInitial extends AdminExamState {}

class AdminExamLoading extends AdminExamState {}

class AdminExamLoaded extends AdminExamState {
  final FinalExamSettingsEntity? settings;
  final List<AdminFinalExamQuestionEntity> questions;

  const AdminExamLoaded({required this.settings, required this.questions});

  @override
  List<Object?> get props => [settings, questions];
}

class AdminExamSaving extends AdminExamState {}

class AdminExamSaved extends AdminExamState {}

class AdminExamError extends AdminExamState {
  final String message;
  const AdminExamError(this.message);
  @override
  List<Object?> get props => [message];
}
