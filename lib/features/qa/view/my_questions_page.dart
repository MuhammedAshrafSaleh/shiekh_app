// lib/features/qa/view/my_questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../cubit/my_questions_cubit.dart';
import '../cubit/my_questions_state.dart';
import '../widgets/question_card.dart';

class MyQuestionsPage extends StatelessWidget {
  const MyQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أسئلتي')),
      body: BlocBuilder<MyQuestionsCubit, MyQuestionsState>(
        builder: (context, state) {
          return switch (state) {
            MyQuestionsInitial() || MyQuestionsLoading() =>
              const Center(child: CircularProgressIndicator()),
            MyQuestionsError(:final message) => ErrorState(
                message: message,
                onRetry: () =>
                    context.read<MyQuestionsCubit>().loadMyQuestions(),
              ),
            MyQuestionsEmpty() => const EmptyState(
                icon: Icons.question_answer_outlined,
                message: 'لم تطرح أي أسئلة بعد',
              ),
            MyQuestionsLoaded(:final questions) => RefreshIndicator(
                onRefresh: () =>
                    context.read<MyQuestionsCubit>().loadMyQuestions(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: questions.length,
                  itemBuilder: (_, index) =>
                      QuestionCard(question: questions[index]),
                ),
              ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
