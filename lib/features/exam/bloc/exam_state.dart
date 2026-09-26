// lib/features/exam/bloc/exam_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/final_exam_attempt_entity.dart';
import '../../../models/final_exam_question_entity.dart';
import '../../../models/final_exam_settings_entity.dart';
import '../data/exam_repository.dart';

abstract class ExamState extends Equatable {
  const ExamState();

  @override
  List<Object?> get props => [];
}

class ExamInitial extends ExamState {}

class ExamLoading extends ExamState {}

/// Blocked before any exam data loads: the current user isn't enrolled in the
/// book (a guest, or a registered-not-enrolled user reaching the page by deep
/// link). The page renders the shared AccountGate for this state.
class ExamGated extends ExamState {
  final String bookId;
  const ExamGated({required this.bookId});

  @override
  List<Object?> get props => [bookId];
}

// Intro screen state — metadata loaded, no active session
class ExamMetaLoaded extends ExamState {
  final String bookId;