// lib/features/practice/bloc/practice_exam_event.dart
import 'package:equatable/equatable.dart';

abstract class PracticeExamEvent extends Equatable {
  const PracticeExamEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on page open — fetches the pool, runs distribution, starts the exam.
class PracticeExamStarted extends PracticeExamEvent {
  const PracticeExamStarted();
}

class PracticeExamAnswerSelected extends PracticeExamEvent {
  final String questionId;
  final String choice;
  const PracticeExamAnswerSelected(this.questionId, this.choice);

  @override
  List<Object?> get props => [questionId, choice];
}

class PracticeExamNavigateTo extends PracticeExamEvent {
  final int index;
  const PracticeExamNavigateTo(this.index);

  @override
  List<Object?> get props => [index];
}

/// Emitted every second while the timer is enabled.
class PracticeExamTick extends PracticeExamEvent {
  const PracticeExamTick();
}

/// User confirmed submission.
class PracticeExamSubmitted extends PracticeExamEvent {
  const PracticeExamSubmitted();
}

/// Timer reached zero — auto-submit.
class PracticeExamAutoSubmitted extends PracticeExamEvent {
  const PracticeExamAutoSubmitted();
}
