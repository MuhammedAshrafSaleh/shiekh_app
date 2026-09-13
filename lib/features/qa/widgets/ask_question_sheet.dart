// lib/features/qa/widgets/ask_question_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../cubit/qa_cubit.dart';
import '../cubit/qa_state.dart';

class AskQuestionSheet extends StatefulWidget {
  const AskQuestionSheet({super.key, required this.bookId, this.lessonId});

  final String bookId;
  final String? lessonId;

  @override
  State<AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<AskQuestionSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  static const _maxChars = 500;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AskQuestionCubit, AskQuestionState>(
      listener: (context, state) {
        if (state is AskQuestionSubmitted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم إرسال سؤالك بنجاح'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (state is AskQuestionError) {
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
        final isSubmitting = state is AskQuestionSubmitting;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter,
                AppSpacing.s3,
                AppSpacing.pageGutter,
                AppSpacing.s5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'اسأل سؤالك',
                    style: GoogleFonts.reemKufi(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),

                  // Anonymity notice
                  Container(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint.withValues(alpha: 0.5),
                      borderRadius: AppRadii.rMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        Expanded(
                          child: Text(
                            'هويّتك ستظهر للشيخ فقط وتبقى مجهولة للطلاب الآخرين',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.inkMuted,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),

                  // Textarea with heritage styling
                  _HeritageTextArea(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !isSubmitting,
                    maxChars: _maxChars,
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Submit
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final canSubmit =
                          value.text.trim().isNotEmpty && !isSubmitting;
                      return SheikhyButton.primary(
                        label: 'إرسال السؤال',
                        isLoading: isSubmitting,
                        onPressed: canSubmit
                            ? () => context.read<AskQuestionCubit>().submit(
                                bookId: widget.bookId,
                                lessonId: widget.lessonId,
                                questionText: _controller.text.trim(),
                              )
                            : null,
                        fullWidth: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeritageTextArea extends StatelessWidget {
  const _HeritageTextArea({
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
        final deco = focusNode.hasFocus
            ? AppDecorations.fieldFocused
            : AppDecorations.field;
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
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
                cursorColor: AppColors.gold,
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'اكتب سؤالك هنا...',
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
