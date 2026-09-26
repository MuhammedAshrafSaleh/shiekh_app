// test/features/exam/exam_bloc_test.dart
//
// Unit tests for ExamBloc — covers:
//   • ExamInProgress state helpers (answeredCount, unansweredCount, questionStatus)
//   • ExamMetaLoaded state helpers (attemptsExhausted, isLocked — CC-13/CC-15/CC-16)
//   • ExamTick decrements secondsRemaining
//   • ExamTick at 1s remaining emits secondsRemaining = 0 then triggers ExamAutoSubmit
//   • ExamAnswerSelected adds/overwrites answer in answers map
//   • ExamNavigateTo changes currentIndex (ignores out-of-bounds)
//   • CC-11 resume: loadSession returns valid session → bloc emits ExamInProgress
//     immediately with restored answers and computed remaining time
//   • CC-11/CC-12 auto-submit: loadSession returns expired session → bloc calls
//     submitExam and emits ExamCompleted
//   • ExamSubmitConfirmed transitions to ExamCompleted via RPC
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_bloc.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_event.dart';
import 'package:sheikhy_app/features/exam/bloc/exam_state.dart';
import 'package:sheikhy_app/features/exam/data/exam_repository.dart';
import 'package:sheikhy_app/models/final_exam_question_entity.dart';
import 'package:sheikhy_app/models/final_exam_settings_entity.dart';

// ---------------------------------------------------------------------------
// Mocks & fallbacks
// ---------------------------------------------------------------------------
class _MockExamRepository extends Mock implements ExamRepository {}