      ),
    );
  }
}

class _ExamQuestionTile extends StatelessWidget {
  final AdminFinalExamQuestionEntity question;
  final int index;

  const _ExamQuestionTile({
    super.key,
    required this.question,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final choices = ['a', 'b', 'c', 'd'];
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 12,
                    child: Text('$index',
                        style: const TextStyle(fontSize: 11))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (question.sourceQuizQuestionId != null)
                  Tooltip(
                    message: 'مستورد من بنك الأسئلة',
                    child: Icon(Icons.link,
                        size: 14,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showDialog(context, question),
                ),
                IconButton(