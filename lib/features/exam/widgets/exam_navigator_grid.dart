// lib/features/exam/widgets/exam_navigator_grid.dart
import 'package:flutter/material.dart';

import '../../../models/final_exam_question_entity.dart';

class ExamNavigatorGrid extends StatelessWidget {
  final List<FinalExamQuestionEntity> questions;
  final Map<String, String> answers;
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  const ExamNavigatorGrid({
    super.key,
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _Legend(
                  color: colorScheme.primary,
                  label: 'محاط',
                ),
                const SizedBox(width: 12),
                _Legend(
                  color: colorScheme.secondary,
                  label: 'تم الإجابة',
                ),
                const SizedBox(width: 12),
                _Legend(
                  color: colorScheme.surfaceContainerHighest,
                  label: 'لم يُجَب',
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.vertical,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final isCurrent = index == currentIndex;
                final isAnswered = answers.containsKey(q.id);

                Color bg;
                Color fg;
                if (isCurrent) {
                  bg = colorScheme.primary;
                  fg = colorScheme.onPrimary;
                } else if (isAnswered) {
                  bg = colorScheme.secondary;
                  fg = colorScheme.onSecondary;
                } else {
                  bg = colorScheme.surfaceContainerHighest;
                  fg = colorScheme.onSurface;
                }

                return InkWell(
                  onTap: () => onNavigate(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                )),
      ],
    );
  }
}
