// lib/features/exam/bloc/exam_event.dart
import 'package:equatable/equatable.dart';

abstract class ExamEvent extends Equatable {
  const ExamEvent();

  @override
  List<Object?> get props => [];
}

// Fired on page open — loads meta or resumes saved session
class ExamLoadRequested extends ExamEvent {
  final String bookId;
  const ExamLoadRequested(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

// User taps "بدء الاختبار" on intro screen
class ExamStartRequested extends ExamEvent {
  const ExamStartRequested();
}

// User selects a choice for a question
class ExamAnswerSelected extends ExamEvent {
  final String questionId;
  final String choice;
  const ExamAnswerSelected(this.questionId, this.choice);

  @override
  List<Object?> get props => [questionId, choice];
}

// User navigates to a specific question index
class ExamNavigateTo extends ExamEvent {
  final int index;
  const ExamNavigateTo(this.index);

  @override
  List<Object?> get props => [index];
}

// Emitted every second by internal timer
class ExamTick extends ExamEvent {
  const ExamTick();
}

// User taps "تسليم الاختبار" (after confirm dialog — CC-17)
class ExamSubmitConfirmed extends ExamEvent {
  const ExamSubmitConfirmed();
}

// Timer reached zero — auto-submit (CC-12)
class ExamAutoSubmit extends ExamEvent {
  const ExamAutoSubmit();
}

// App was backgrounded and returned while the exam was in progress
class ExamBackgroundLeave extends ExamEvent {
  const ExamBackgroundLeave();
}
