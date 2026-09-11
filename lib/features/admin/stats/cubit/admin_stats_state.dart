// lib/features/admin/stats/cubit/admin_stats_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/lesson_entity.dart';
import '../../../../models/student_question_entity.dart';
import '../data/admin_stats_repository.dart';

abstract class AdminStatsState extends Equatable {
  const AdminStatsState();
  @override
  List<Object?> get props => [];
}

class AdminStatsInitial extends AdminStatsState {}

class AdminStatsLoading extends AdminStatsState {}

class AdminStatsLoaded extends AdminStatsState {
  final List<LessonEntity> lessons;
  final BookStats stats;
  final List<StudentQuestionEntity> questions;

  const AdminStatsLoaded({
    required this.lessons,
    required this.stats,
    required this.questions,
  });

  @override
  List<Object?> get props => [lessons, stats, questions];
}

class AdminStatsError extends AdminStatsState {
  final String message;
  const AdminStatsError(this.message);
  @override
  List<Object?> get props => [message];
}
