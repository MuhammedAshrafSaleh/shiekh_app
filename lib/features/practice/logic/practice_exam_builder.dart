// lib/features/practice/logic/practice_exam_builder.dart
import 'dart:math';

import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../models/quiz_question_entity.dart';
import '../data/practice_repository.dart';
import 'practice_distribution.dart';
import 'practice_exam_config.dart';

/// Fetches the answer-free question pool for [config]'s lessons and draws the
/// ordered exam via the pure distribution function. Shared by the loading
/// screen (prefetch) and the exam bloc (fetch / retry path).
Future<Either<Failure, List<QuizQuestionEntity>>> buildPracticeExam(
  PracticeRepository repo,
  PracticeExamConfig config,
  Random random,
) async {
  final poolResult = await repo.getQuestionPool(config.lessonIds);
  return poolResult.fold((f) => Left(f), (questions) {
    final poolByLesson = <String, List<String>>{};
    final byId = <String, QuizQuestionEntity>{};
    for (final q in questions) {
      poolByLesson.putIfAbsent(q.lessonId, () => []).add(q.id);
      byId[q.id] = q;
    }

    final orderedIds = distributeQuestions(
      poolByLesson,
      config.questionCount,
      random,
    );

    if (orderedIds.length < kMinPracticeQuestions) {
      return Left(ValidationFailure('تعذّر إنشاء الاختبار، اختر محاضرات أخرى'));
    }

    return Right([for (final id in orderedIds) byId[id]!]);
  });
}
