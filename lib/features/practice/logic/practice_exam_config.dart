// lib/features/practice/logic/practice_exam_config.dart
import 'package:equatable/equatable.dart';

import '../../../models/quiz_question_entity.dart';

/// The student's chosen settings for one practice exam, passed from the setup
/// screen through the loading screen into the exam runner.
class PracticeExamConfig extends Equatable {
  final List<String> lessonIds;
  final int questionCount;
  final bool timerEnabled;

  /// Minutes; meaningful only when [timerEnabled] is true.
  final int timeLimitMinutes;

  const PracticeExamConfig({
    required this.lessonIds,
    required this.questionCount,
    required this.timerEnabled,
    required this.timeLimitMinutes,
  });

  /// Null when the timer is off — what gets stored on the attempt.
  int? get effectiveTimeLimit => timerEnabled ? timeLimitMinutes : null;

  @override
  List<Object?> get props => [
    lessonIds,
    questionCount,
    timerEnabled,
    timeLimitMinutes,
  ];
}

/// Passed from the loading screen to the exam route: the config plus the
/// questions prefetched while the quotes were showing (null if the student
/// skipped before the prefetch finished, or it failed — the exam then builds
/// them itself and shows a retry on error).
class PracticeExamLaunch {
  final PracticeExamConfig config;
  final List<QuizQuestionEntity>? prebuiltQuestions;

  const PracticeExamLaunch(this.config, this.prebuiltQuestions);
}
