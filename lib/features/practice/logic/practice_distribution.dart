// lib/features/practice/logic/practice_distribution.dart
import 'dart:math';

/// Minimum questions a practice exam may contain.
const int kMinPracticeQuestions = 20;

/// Hard ceiling on questions in a single practice exam.
const int kMaxPracticeQuestions = 100;

/// The maximum number of questions the student may request given the total
/// [totalAvailable] approved questions across the selected lessons:
/// `min(100, totalAvailable)`.
int maxPracticeCount(int totalAvailable) =>
    totalAvailable < kMaxPracticeQuestions
    ? totalAvailable
    : kMaxPracticeQuestions;

/// Whether a practice exam can be started: at least [kMinPracticeQuestions]
/// questions must be available across the selected lessons. When this is
/// false the UI blocks start and shows «اختار محاضرات أكتر».
bool canStartPractice(int totalAvailable) =>
    totalAvailable >= kMinPracticeQuestions;

/// Builds the ordered list of question IDs for a practice exam.
///
/// Behaviour:
/// - Splits [count] evenly across the lessons in [pool]; each lesson gets
///   `count ~/ lessons`. The `count % lessons` remainder is handed out, one
///   extra each, to randomly chosen distinct lessons
///   (e.g. 25 over 10 lessons → 2 each + 5 lessons get a 3rd).
/// - Questions within each lesson are picked at random.
/// - If a lesson has fewer questions than its share, it contributes all of
///   them and the gap is backfilled at random from spare questions in the
///   other lessons.
/// - The final question ORDER is shuffled. (Choice/option order is never
///   shuffled — choices always display as a/b/c/d.)
///
/// [pool] maps `lessonId` → that lesson's available (approved, non-deleted)
/// question IDs. Returns at most `min(count, total available)` IDs, with no
/// duplicates. Pure and deterministic for a given [rng].
List<String> distributeQuestions(
  Map<String, List<String>> pool,
  int count,
  Random rng,
) {
  final lessons = pool.keys.toList();
  final total = pool.values.fold<int>(0, (sum, ids) => sum + ids.length);

  // Clamp the request to what actually exists; never exceed the real pool.
  final target = count < 0 ? 0 : (count > total ? total : count);
  if (lessons.isEmpty || target == 0) return <String>[];

  final n = lessons.length;
  final base = target ~/ n;
  final remainder = target % n;

  // Even base share for every lesson.
  final allocation = {for (final l in lessons) l: base};

  // Hand the remainder to `remainder` randomly chosen distinct lessons.
  final lessonOrder = [...lessons]..shuffle(rng);
  for (var i = 0; i < remainder; i++) {
    final l = lessonOrder[i];
    allocation[l] = allocation[l]! + 1;
  }

  final selected = <String>[];
  final spares = <String>[];

  // Take each lesson's share at random; stash the rest as backfill spares.
  for (final l in lessons) {
    final shuffled = [...pool[l]!]..shuffle(rng);
    final want = allocation[l]!;
    final take = want <= shuffled.length ? want : shuffled.length;
    selected.addAll(shuffled.sublist(0, take));
    spares.addAll(shuffled.sublist(take));
  }

  // Backfill any shortfall (short lessons) from other lessons' spares.
  final shortfall = target - selected.length;
  if (shortfall > 0) {
    spares.shuffle(rng);
    selected.addAll(spares.take(shortfall));
  }

  // Shuffle the final question order.
  selected.shuffle(rng);
  return selected;
}
