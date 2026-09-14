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

  /// Number of questions available in the lesson question bank for this book
  /// (source for "استيراد من البنك"). Not the count attached to the exam.
  final int bankCount;

  const AdminExamLoaded({
    required this.settings,
    required this.questions,
    this.bankCount = 0,
  });

  @override
  List<Object?> get props => [settings, questions, bankCount];
}

class AdminExamSaving extends AdminExamState {}

class AdminExamSaved extends AdminExamState {}

class AdminExamError extends AdminExamState {
  final String message;
  const AdminExamError(this.message);
  @override
  List<Object?> get props => [message];
}
