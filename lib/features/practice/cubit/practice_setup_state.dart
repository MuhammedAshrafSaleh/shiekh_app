// lib/features/practice/cubit/practice_setup_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/practice_attempt_summary_entity.dart';
import '../../../models/practice_eligible_lesson_entity.dart';
import '../logic/practice_distribution.dart';

abstract class PracticeSetupState extends Equatable {
  const PracticeSetupState();

  @override
  List<Object?> get props => [];
}

class PracticeSetupInitial extends PracticeSetupState {}

class PracticeSetupLoading extends PracticeSetupState {}

class PracticeSetupError extends PracticeSetupState {
  final String message;
  const PracticeSetupError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Loaded setup screen: eligible lessons + past attempts + the student's
/// current selections (lessons, question count, timer).
class PracticeSetupLoaded extends PracticeSetupState {
  final List<PracticeEligibleLessonEntity> lessons;
  final List<PracticeAttemptSummaryEntity> history;
  final Set<String> selectedLessonIds;
  final int questionCount;
  final bool timerEnabled;
  final int timeLimitMinutes;

  const PracticeSetupLoaded({
    required this.lessons,
    required this.history,
    required this.selectedLessonIds,
    required this.questionCount,
    required this.timerEnabled,
    required this.timeLimitMinutes,
  });

  /// Total approved questions across the currently selected lessons.
  int get totalAvailable => lessons
      .where((l) => selectedLessonIds.contains(l.lessonId))
      .fold(0, (sum, l) => sum + l.questionCount);

  /// Upper bound for the count slider: `min(100, totalAvailable)`.
  int get maxCount => maxPracticeCount(totalAvailable);

  /// Whether enough questions are selected to begin (≥ 20).
  bool get canStart => canStartPractice(totalAvailable);

  PracticeSetupLoaded copyWith({
    Set<String>? selectedLessonIds,
    int? questionCount,
    bool? timerEnabled,
    int? timeLimitMinutes,
  }) {
    return PracticeSetupLoaded(
      lessons: lessons,
      history: history,
      selectedLessonIds: selectedLessonIds ?? this.selectedLessonIds,
      questionCount: questionCount ?? this.questionCount,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
    );
  }

  @override
  List<Object?> get props => [
    lessons,
    history,
    selectedLessonIds,
    questionCount,
    timerEnabled,
    timeLimitMinutes,
  ];
}
