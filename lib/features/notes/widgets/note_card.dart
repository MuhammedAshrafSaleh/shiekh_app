// lib/features/notes/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_duration.dart';
import '../../../models/lesson_note_entity.dart';
import '../cubit/notes_cubit.dart';
import 'note_editor_sheet.dart';

class NoteCard extends StatelessWidget {
  final LessonNoteEntity note;
  final String bookId;
  final VoidCallback? onSeek;

  const NoteCard({
    super.key,
    required this.note,
    required this.bookId,
    this.onSeek,
  });

  void _seekToNote(BuildContext context) {
    context.push(
      '/lessons/${note.lessonId}?bookId=$bookId&t=${note.positionSeconds}',
    );
  }

  Future<void> _edit(BuildContext context) async {
    await NoteEditorSheet.showEdit(context, note: note);
    if (context.mounted) {
      context.read<NotesCubit>().refreshAfterEdit();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        title: const Text('حذف الملحوظة'),
        content: const Text('هل أنت متأكد من حذف هذه الملحوظة؟'),
        actions: [
          TextButton(
            onPressed: () => dialogCtx.pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => dialogCtx.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    context.read<NotesCubit>().delete(note.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حذف الملحوظة'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = formatNoteTimestamp(
      Duration(seconds: note.positionSeconds),
    );

    return InkWell(
      onTap: onSeek ?? () => _seekToNote(context),
      borderRadius: AppRadii.rMd,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.pageGutter,
          0,
          AppSpacing.pageGutter,
          AppSpacing.s3,
        ),
        decoration: AppDecorations.card,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp + actions row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.s2,
                      vertical: AppSpacing.s1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadii.rSm,
                    ),
                    child: Text(
                      timestamp,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'تعديل',
                    onPressed: () => _edit(context),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'حذف',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              // Note text
              Text(
                note.noteText,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
