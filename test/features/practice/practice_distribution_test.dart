// test/features/practice/practice_distribution_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/features/practice/logic/practice_distribution.dart';

/// Builds a pool of [lessonCount] lessons each with [perLesson] uniquely-named
/// question IDs, e.g. L0Q0, L0Q1, … so every ID maps back to one lesson.
Map<String, List<String>> buildPool(int lessonCount, int perLesson) {
  return {
    for (var l = 0; l < lessonCount; l++)
      'L$l': [for (var q = 0; q < perLesson; q++) 'L${l}Q$q'],
  };
}

/// Reverse index: question ID → owning lesson ID.
Map<String, String> reverseIndex(Map<String, List<String>> pool) {
  return {
    for (final entry in pool.entries)
      for (final id in entry.value) id: entry.key,
  };
}

/// Counts how many selected questions came from each lesson.
Map<String, int> perLessonCounts(
  List<String> selected,
  Map<String, String> rev,
) {
  final counts = <String, int>{};
  for (final id in selected) {
    final lesson = rev[id]!;
    counts[lesson] = (counts[lesson] ?? 0) + 1;
  }
  return counts;
}

void main() {
  group('maxPracticeCount', () {
    test('caps at 100 when more are available', () {
      expect(maxPracticeCount(250), 100);
      expect(maxPracticeCount(100), 100);
    });

    test('returns the real total when below the ceiling', () {
      expect(maxPracticeCount(15), 15);
      expect(maxPracticeCount(0), 0);
    });
  });

  group('canStartPractice', () {
    test('false below the minimum', () {
      expect(canStartPractice(0), isFalse);
      expect(canStartPractice(19), isFalse);
    });

    test('true at or above the minimum', () {
      expect(canStartPractice(20), isTrue);
      expect(canStartPractice(21), isTrue);
    });
  });

  group('distributeQuestions', () {
    test('even split across lessons with no remainder', () {
      final pool = buildPool(4, 10); // 40 available
      final rev = reverseIndex(pool);
      final result = distributeQuestions(pool, 20, Random(1));

      expect(result.length, 20);
      expect(result.toSet().length, 20, reason: 'no duplicates');
      final counts = perLessonCounts(result, rev);
      for (final l in pool.keys) {
        expect(counts[l], 5, reason: '$l should contribute exactly 5');
      }
    });

    test('remainder is spread one-each across random lessons (25 / 10)', () {
      final pool = buildPool(10, 10); // 100 available
      final rev = reverseIndex(pool);
      final result = distributeQuestions(pool, 25, Random(7));

      expect(result.length, 25);
      expect(result.toSet().length, 25);

      final counts = perLessonCounts(result, rev);
      // Base = 2 each; 5 lessons get a 3rd. No lesson gets 2 extra.
      final threes = counts.values.where((c) => c == 3).length;
      final twos = counts.values.where((c) => c == 2).length;
      expect(threes, 5);
      expect(twos, 5);
      expect(counts.values.every((c) => c == 2 || c == 3), isTrue);
    });

    test('short lesson contributes all it has; gap backfilled from others', () {
      final pool = {
        'A': ['A0'], // only 1 question
        'B': [for (var q = 0; q < 20; q++) 'B$q'],
        'C': [for (var q = 0; q < 20; q++) 'C$q'],
      };
      final rev = reverseIndex(pool);
      final result = distributeQuestions(pool, 20, Random(3));

      expect(result.length, 20);
      expect(result.toSet().length, 20);
      // A can only ever contribute its single question.
      final counts = perLessonCounts(result, rev);
      expect(counts['A'], 1);
      expect(result.contains('A0'), isTrue);
      // The remaining 19 come from B and C.
      expect((counts['B'] ?? 0) + (counts['C'] ?? 0), 19);
    });

    test('count larger than the pool returns everything, de-duplicated', () {
      final pool = buildPool(3, 5); // 15 available
      final result = distributeQuestions(pool, 100, Random(5));

      expect(result.length, 15);
      expect(result.toSet().length, 15);
      // Every question in the pool is present.
      final all = pool.values.expand((e) => e).toSet();
      expect(result.toSet(), all);
    });

    test('all selected IDs belong to the pool', () {
      final pool = buildPool(6, 8);
      final valid = pool.values.expand((e) => e).toSet();
      final result = distributeQuestions(pool, 30, Random(11));

      expect(result.every(valid.contains), isTrue);
    });

    test('deterministic for a given seed', () {
      final pool = buildPool(5, 12);
      final a = distributeQuestions(pool, 23, Random(42));
      final b = distributeQuestions(pool, 23, Random(42));
      expect(a, equals(b));
    });

    test('empty pool yields an empty list', () {
      expect(
        distributeQuestions(<String, List<String>>{}, 20, Random(1)),
        isEmpty,
      );
    });

    test('zero or negative count yields an empty list', () {
      final pool = buildPool(3, 10);
      expect(distributeQuestions(pool, 0, Random(1)), isEmpty);
      expect(distributeQuestions(pool, -5, Random(1)), isEmpty);
    });
  });
}
