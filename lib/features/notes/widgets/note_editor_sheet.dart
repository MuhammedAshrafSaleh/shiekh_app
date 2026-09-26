// lib/features/notes/widgets/note_editor_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../models/lesson_note_entity.dart';
import '../cubit/note_editor_cubit.dart';
import '../cubit/note_editor_state.dart';
import '../data/notes_repository.dart';

enum NoteEditorMode { add, edit }

/// A modal bottom sheet for adding or editing a lesson note.
///
/// Provides its own [NoteEditorCubit] — call via [NoteEditorSheet.show].
/// The sheet pauses the video before opening; the caller resumes it after the
/// returned Future completes (regardless of how the sheet was dismissed).
class NoteEditorSheet extends StatefulWidget {
  final NoteEditorMode mode;

  // Add-mode fields
  final String? lessonId;
  final String? bookId;
  final int? positionSeconds;

  // Edit-mode field
  final LessonNoteEntity? existingNote;

  const NoteEditorSheet._({
    required this.mode,
    this.lessonId,
    this.bookId,
    this.positionSeconds,
    this.existingNote,
  });

  /// Shows the sheet in add mode. Returns after the sheet is dismissed
  /// (whether saved or cancelled).
  static Future<void> show(
    BuildContext context, {
    required String lessonId,
    required String bookId,
    required int positionSeconds,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => BlocProvider(
        create: (ctx) => NoteEditorCubit(ctx.read<NotesRepository>()),
        child: NoteEditorSheet._(
          mode: NoteEditorMode.add,
          lessonId: lessonId,
          bookId: bookId,
          positionSeconds: positionSeconds,
        ),
      ),
    );
  }

  /// Shows the sheet in edit mode (text only). Returns after dismissed.
  static Future<void> showEdit(
    BuildContext context, {
    required LessonNoteEntity note,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => BlocProvider(
        create: (ctx) => NoteEditorCubit(ctx.read<NotesRepository>()),
        child: NoteEditorSheet._(
          mode: NoteEditorMode.edit,
          existingNote: note,
        ),
      ),
    );
  }

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  static const _maxChars = 1000;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.existingNote?.noteText ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.mode == NoteEditorMode.add) {
      context.read<NoteEditorCubit>().save(
        lessonId: widget.lessonId!,
        bookId: widget.bookId!,
        positionSeconds: widget.positionSeconds!,
        text: text,
      );
    } else {
      context.read<NoteEditorCubit>().updateText(
        noteId: widget.existingNote!.id,
        text: text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.mode == NoteEditorMode.add
                    ? 'تمت إضافة الملحوظة'
                    : 'تم تعديل الملحوظة',
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (state is NoteEditorError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is NoteEditorSaving;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s3,
              AppSpacing.pageGutter,
              AppSpacing.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadii.rPill,
                    ),
                  ),
                ),

                // Title
                Text(
                  widget.mode == NoteEditorMode.add
                      ? 'إضافة ملحوظة'
                      : 'تعديل الملحوظة',
                  style: GoogleFonts.reemKufi(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),

                // Text field
                _NoteTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isSaving,
                  maxChars: _maxChars,
                ),
                const SizedBox(height: AppSpacing.s5),

                // Save button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canSave = value.text.trim().isNotEmpty && !isSaving;
                    return SheikhyButton.primary(
                      label: 'حفظ',
                      isLoading: isSaving,
                      onPressed: canSave ? () => _onSave(context) : null,
                      fullWidth: true,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoteTextField extends StatelessWidget {
  const _NoteTextField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.maxChars,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final deco =
            focusNode.hasFocus ? AppDecorations.fieldFocused : AppDecorations.field;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: deco,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s4,
                AppSpacing.s3,
                AppSpacing.s4,
                AppSpacing.s3,
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                maxLines: 5,
                maxLength: maxChars,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
                cursorColor: AppColors.gold,
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'اكتب ملحوظتك هنا...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final count = value.text.length;
                final nearLimit = count > maxChars * 0.9;
                return Text(
                  '$count / $maxChars',
                  style: AppTextStyles.caption.copyWith(
                    color: nearLimit ? AppColors.danger : AppColors.inkFaint,
                    letterSpacing: 0,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
