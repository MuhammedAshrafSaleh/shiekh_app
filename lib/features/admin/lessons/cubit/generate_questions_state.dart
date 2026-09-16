// lib/features/admin/lessons/cubit/generate_questions_state.dart
import 'package:equatable/equatable.dart';

abstract class GenerateQuestionsState extends Equatable {
  const GenerateQuestionsState();
  @override
  List<Object?> get props => [];
}

class GenerateQuestionsInitial extends GenerateQuestionsState {}

/// Phase one of the link-based flow: transcribing the lesson's video/audio
/// (~65–100 s). Drives the "جاري تفريغ المحاضرة..." loading UI.
class GenerateQuestionsTranscribing extends GenerateQuestionsState {}

/// Long-running generation in progress (30–130+ s). Drives the "جاري توليد
/// الأسئلة..." loading UI. Also phase two of the link-based flow.
class GenerateQuestionsGenerating extends GenerateQuestionsState {}

class GenerateQuestionsSuccess extends GenerateQuestionsState {
  final int insertedCount;
  const GenerateQuestionsSuccess(this.insertedCount);
  @override
  List<Object?> get props => [insertedCount];
}

class GenerateQuestionsError extends GenerateQuestionsState {
  final String message;

  /// Set only when transcription succeeded but question generation then failed:
  /// the transcript is already saved server-side, so the page can offer a
  /// one-tap "generate only" retry without re-transcribing.
  final String? savedTranscript;

  const GenerateQuestionsError(this.message, {this.savedTranscript});
  @override
  List<Object?> get props => [message, savedTranscript];
}
