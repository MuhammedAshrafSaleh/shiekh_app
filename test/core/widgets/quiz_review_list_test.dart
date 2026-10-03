// test/core/widgets/quiz_review_list_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/core/widgets/quiz_review_list.dart';

Widget _host(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  group('QuizReviewCard', () {
    testWidgets('normal item shows question + 4 choices, no lecture chip', (
      tester,
    ) async {
      const item = QuizReviewItem(
        questionText: 'ما حكم كذا؟',
        choiceA: 'أ-نص',
        choiceB: 'ب-نص',
        choiceC: 'ج-نص',
        choiceD: 'د-نص',
        correctChoice: 'b',
        userAnswer: 'a',
        isCorrect: false,
      );

      await tester.pumpWidget(
        _host(const QuizReviewCard(index: 0, item: item)),
      );

      expect(find.text('ما حكم كذا؟'), findsOneWidget);
      expect(find.text('أ-نص'), findsOneWidget);
      expect(find.text('د-نص'), findsOneWidget);
      // No source-lecture chip for a lesson-quiz item.
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
      expect(find.text('هذا السؤال تم حذفه'), findsNothing);
    });

    testWidgets('lectureTitle renders the source chip', (tester) async {
      const item = QuizReviewItem(
        questionText: 'سؤال',
        choiceA: 'أ',
        choiceB: 'ب',
        choiceC: 'ج',
        choiceD: 'د',
        correctChoice: 'a',
        userAnswer: 'a',
        isCorrect: true,
        lectureTitle: 'المحاضرة الأولى',
      );

      await tester.pumpWidget(
        _host(const QuizReviewCard(index: 1, item: item)),
      );

      expect(find.text('المحاضرة الأولى'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('deleted item shows tombstone and no options', (tester) async {
      const item = QuizReviewItem(
        questionText: null,
        choiceA: null,
        choiceB: null,
        choiceC: null,
        choiceD: null,
        correctChoice: null,
        userAnswer: 'c',
        isCorrect: false,
        isDeleted: true,
      );

      await tester.pumpWidget(
        _host(const QuizReviewCard(index: 2, item: item)),
      );

      expect(find.text('هذا السؤال تم حذفه'), findsOneWidget);
      // No choice letters rendered for a tombstone.
      expect(find.text('أ'), findsNothing);
    });
  });
}
