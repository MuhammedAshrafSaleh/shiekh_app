// lib/features/qa/view/book_qa_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../cubit/qa_cubit.dart';
import '../cubit/qa_state.dart';
import '../data/qa_repository.dart';
import '../widgets/ask_question_sheet.dart';
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

  void _openAskSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider(
        create: (ctx) => AskQuestionCubit(ctx.read<QaRepository>()),
        child: AskQuestionSheet(bookId: widget.bookId),
      ),
    ).then((_) {
      if (mounted) {
        context.read<QaCubit>().loadQuestions(widget.bookId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأسئلة والأجوبة')),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAskSheet,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('اسأل سؤالاً'),
      ),
      body: BlocBuilder<QaCubit, QaState>(
        builder: (context, state) {
          return switch (state) {
            QaInitial() ||
            QaLoading() => const Center(child: CircularProgressIndicator()),
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
                padding: EdgeInsets.zero,
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
