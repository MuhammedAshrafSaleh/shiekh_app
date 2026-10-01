// test/core/widgets/bank_import_page_test.dart
//
// Widget test guarding the layout regression where the bottom import button
// (in Scaffold.bottomNavigationBar) expanded to fill the whole screen and
// painted over the AppBar + lessons list. Asserts the AppBar, lesson rows, and
// a normally-sized import button all render.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sheikhy_app/core/errors/failures.dart';
import 'package:sheikhy_app/core/widgets/bank_import_page.dart';
import 'package:sheikhy_app/core/widgets/sheikhy_button.dart';
import 'package:sheikhy_app/features/admin/shared/data/question_bank_repository.dart';
import 'package:sheikhy_app/models/bank_lesson_summary_entity.dart';

class _MockRepo extends Mock implements QuestionBankRepository {}

void main() {
  late _MockRepo repo;

  final lessons = [
    const BankLessonSummaryEntity(
      lessonId: 'A',
      title: 'الدرس الأول',
      orderIndex: 0,
      approvedCount: 3,
    ),
    const BankLessonSummaryEntity(
      lessonId: 'B',
      title: 'الدرس الثاني',
      orderIndex: 1,
      approvedCount: 5,
    ),
  ];

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getBankLessonSummaries(any()))
        .thenAnswer((_) async => Right(lessons));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<QuestionBankRepository>.value(
          value: repo,
          child: const BankImportPage(
            bookId: 'book-1',
            alreadyAddedSourceIds: {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders AppBar, lesson rows, and a normal-height import button',
      (tester) async {
    await pump(tester);

    // AppBar is visible (not covered by the bottom button).
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('استيراد من البنك'), findsOneWidget);

    // Lessons list rendered.
    expect(find.text('الدرس الأول'), findsOneWidget);
    expect(find.text('الدرس الثاني'), findsOneWidget);

    // Import button present, disabled label, and NOT full-screen height.
    expect(find.text('استيراد (0)'), findsOneWidget);
    final buttonSize = tester.getSize(find.byType(SheikhyButton));
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(buttonSize.height, lessThan(100));
    expect(buttonSize.height, lessThan(screenHeight / 2));
  });

  testWidgets('shows empty state when the bank has no lessons', (tester) async {
    when(() => repo.getBankLessonSummaries(any()))
        .thenAnswer((_) async => const Right(<BankLessonSummaryEntity>[]));
    await pump(tester);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('لا توجد أسئلة في البنك'), findsOneWidget);
  });

  testWidgets('shows error state when the RPC fails', (tester) async {
    when(() => repo.getBankLessonSummaries(any()))
        .thenAnswer((_) async => Left(ServerFailure('فشل')));
    await pump(tester);

    expect(find.text('فشل'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
