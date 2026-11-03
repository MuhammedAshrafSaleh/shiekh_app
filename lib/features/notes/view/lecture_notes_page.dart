// lib/features/notes/view/lecture_notes_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../cubit/notes_cubit.dart';
import '../cubit/notes_state.dart';
import '../widgets/note_card.dart';

/// Level 2 — all notes for a single lecture, ascending by position_seconds.
/// System back returns to the book screen's المحفوظات tab (Level 1).
class LectureNotesPage extends StatefulWidget {
  final String bookId;
  final String lessonId;
  final String lessonTitle;

  const LectureNotesPage({
    super.key,
    required this.bookId,
    required this.lessonId,
    required this.lessonTitle,
  });

  @override
  State<LectureNotesPage> createState() => _LectureNotesPageState();
}

class _LectureNotesPageState extends State<LectureNotesPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          _LectureNotesHeader(
            title: widget.lessonTitle,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: BlocBuilder<NotesCubit, NotesState>(
              builder: (context, state) {
                return switch (state) {
                  NotesInitial() || NotesLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  NotesError(:final message) => SheikhyErrorState(
                    heading: 'تعذّر تحميل الملحوظات',
                    message: message,
                    onRetry: () => context.read<NotesCubit>().load(),
                  ),
                  NotesLoaded(:final notes) => _NotesList(
                    notes:
                        notes
                            .where((n) => n.lessonId == widget.lessonId)
                            .toList()
                          ..sort(
                            (a, b) =>
                                a.positionSeconds.compareTo(b.positionSeconds),
                          ),
                    bookId: widget.bookId,
                    onRetry: () => context.read<NotesCubit>().load(),
                  ),
                  _ => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  final List notes;
  final String bookId;
  final VoidCallback onRetry;

  const _NotesList({
    required this.notes,
    required this.bookId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const SheikhyEmptyState(
        icon: Icons.notes_outlined,
        heading: 'لا توجد ملحوظات',
        subtitle: 'لم تعد هناك ملحوظات لهذه المحاضرة',
      );
    }

    return ListView.builder(
      padding: EdgeInsetsDirectional.only(
        top: AppSpacing.s3,
        bottom: AppSpacing.s3 + context.safeBottom,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) =>
          NoteCard(note: notes[index], bookId: bookId),
    );
  }
}

class _LectureNotesHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _LectureNotesHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppBorders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.pageGutter,
            AppSpacing.s2,
            AppSpacing.s2,
            AppSpacing.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الملحوظات',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      title,
                      style: GoogleFonts.reemKufi(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: AppColors.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'رجوع',
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
