// lib/features/qa/view/book_qa_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../cubit/qa_cubit.dart';
import '../cubit/qa_state.dart';
import '../widgets/question_card.dart';

class BookQaPage extends StatefulWidget {
  final String bookId;

  const BookQaPage({super.key, required this.bookId});

  @override
  State<BookQaPage> createState() => _BookQaPageState();
}

class _BookQaPageState extends State<BookQaPage> {
  @override
  void initState() {
    super.initState();
    context.read<QaCubit>().loadQuestions(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأسئلة والأجوبة')),
      body: BlocBuilder<QaCubit, QaState>(
        builder: (context, state) {
          return switch (state) {
            QaInitial() || QaLoading() =>
              const Center(child: CircularProgressIndicator()),
            QaError(:final message) => ErrorState(
                message: message,
                onRetry: () =>
                    context.read<QaCubit>().loadQuestions(widget.bookId),
              ),
            QaEmpty() => const EmptyState(
                icon: Icons.question_answer_outlined,
                message: 'لا توجد أسئلة بعد، كن أول من يسأل!',
              ),
            QaLoaded(:final questions) => RefreshIndicator(
                onRefresh: () =>
                    context.read<QaCubit>().loadQuestions(widget.bookId),
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
