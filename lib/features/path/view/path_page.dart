// lib/features/path/view/path_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../models/book_with_progress_entity.dart';
import '../cubit/path_cubit.dart';
import '../cubit/path_state.dart';
import '../widgets/book_progress_card.dart';

class PathPage extends StatelessWidget {
  const PathPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مساري'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'جارية الآن'),
              Tab(text: 'لم تبدأ بعد'),
            ],
          ),
        ),
        body: BlocBuilder<PathCubit, PathState>(
          builder: (context, state) {
            if (state is PathLoading || state is PathInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PathError) {
              return ErrorState(
                message: state.message,
                onRetry: () => context.read<PathCubit>().loadPath(),
              );
            }

            if (state is PathEmpty) {
              return TabBarView(
                children: [
                  _emptyTab('لم تبدأ أي كتاب بعد', Icons.menu_book_outlined),
                  _emptyTab(
                    'لم تنضم إلى أي كتاب بعد',
                    Icons.library_books_outlined,
                  ),
                ],
              );
            }

            if (state is PathLoaded) {
              final inProgress = state.books
                  .where((b) => b.progress > 0 && b.progress < 1.0)
                  .toList();
              final notStarted = state.books
                  .where((b) => b.progress == 0)
                  .toList();

              return RefreshIndicator(
                onRefresh: () => context.read<PathCubit>().loadPath(),
                child: TabBarView(
                  children: [
                    _BookList(
                      books: inProgress,
                      emptyMessage: 'لا توجد كتب جارية حاليًا',
                      emptyIcon: Icons.play_circle_outline,
                    ),
                    _BookList(
                      books: notStarted,
                      emptyMessage: 'أحسنت! بدأت جميع الكتب المسجل فيها',
                      emptyIcon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _emptyTab(String message, IconData icon) {
    return EmptyState(icon: icon, message: message);
  }
}

class _BookList extends StatelessWidget {
  final List<BookWithProgressEntity> books;
  final String emptyMessage;
  final IconData emptyIcon;

  const _BookList({
    required this.books,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return EmptyState(icon: emptyIcon, message: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) => BookProgressCard(item: books[index]),
    );
  }
}
