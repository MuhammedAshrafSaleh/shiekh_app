import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/features/admin/exam/view/bank_import_page.dart';
import 'package:sheikhy_app/models/admin_quiz_question_entity.dart';

AdminQuizQuestionEntity _q(String id) => AdminQuizQuestionEntity(
  id: id,
  lessonId: 'l1',
  orderIndex: 0,
  questionText: 'ما حكم الصلاة في وقتها؟ سؤال طويل جدا لاختبار الالتفاف',
  choiceA: 'واجب',
  choiceB: 'مستحب',
  choiceC: 'مباح',
  choiceD: 'مكروه',
  correctChoice: 'a',
);

void main() {
  testWidgets('BankImportPage renders question cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: BankImportPage(
          bankQuestions: [_q('1'), _q('2')],
          alreadyAddedSourceIds: const {'2'},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ما حكم الصلاة'), findsWidgets);
    expect(find.text('تمت الإضافة'), findsOneWidget);
    expect(find.text('واجب'), findsWidgets);
    expect(tester.getSize(find.byType(ListView).first).height, greaterThan(0));
  });
}
