// lib/features/practice/cubit/practice_setup_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/practice_repository.dart';
import '../logic/practice_distribution.dart';
import 'practice_setup_state.dart';

/// Timer bounds for a practice exam (minutes).
const int kPracticeTimerMin = 15;
const int kPracticeTimerMax = 120;
const int kPracticeTimerStep = 5;
const int kPracticeTimerDefault = 30;

class PracticeSetupCubit extends Cubit<PracticeSetupState> {
  final PracticeRepository _repo;

  PracticeSetupCubit(this._repo) : super(PracticeSetupInitial());

  Future<void> load() async {
    emit(PracticeSetupLoading());

    final lessonsResult = await _repo.getEligibleLessons();
    if (lessonsResult.isLeft()) {
      emit(PracticeSetupError(lessonsResult.fold((f) => f.message, (_) => '')));
      return;
    }

    final historyResult = await _repo.getHistory();
    if (historyResult.isLeft()) {
      emit(PracticeSetupError(historyResult.fold((f) => f.message, (_) => '')));
      return;
    }

    emit(
      PracticeSetupLoaded(
        lessons: lessonsResult.getOrElse(() => const []),
        history: historyResult.getOrElse(() => const []),
        selectedLessonIds: const {},
        questionCount: kMinPracticeQuestions,
        timerEnabled: false,
        timeLimitMinutes: kPracticeTimerDefault,
      ),
    );
  }

  void toggleLesson(String lessonId) {
    final s = state;
    if (s is! PracticeSetupLoaded) return;

    final selected = {...s.selectedLessonIds};
    if (!selected.remove(lessonId)) selected.add(lessonId);

    emit(s.copyWith(selectedLessonIds: selected));
    _clampCount();
  }

  void setCount(int count) {
    final s = state;
    if (s is! PracticeSetupLoaded) return;
    emit(s.copyWith(questionCount: _clamp(count, s.maxCount)));
  }

  void toggleTimer(bool enabled) {
    final s = state;
    if (s is! PracticeSetupLoaded) return;
    emit(s.copyWith(timerEnabled: enabled));
  }

  void setTimeLimit(int minutes) {
    final s = state;
    if (s is! PracticeSetupLoaded) return;
    final clamped = minutes.clamp(kPracticeTimerMin, kPracticeTimerMax).toInt();
    emit(s.copyWith(timeLimitMinutes: clamped));
  }

  /// Re-clamp the chosen count after a selection change (the max may shrink).
  void _clampCount() {
    final s = state;
    if (s is! PracticeSetupLoaded) return;
    final clamped = _clamp(s.questionCount, s.maxCount);
    if (clamped != s.questionCount) {
      emit(s.copyWith(questionCount: clamped));
    }
  }

  int _clamp(int count, int maxCount) {
    final upper = maxCount < kMinPracticeQuestions
        ? kMinPracticeQuestions
        : maxCount;
    return count.clamp(kMinPracticeQuestions, upper).toInt();
  }
}
