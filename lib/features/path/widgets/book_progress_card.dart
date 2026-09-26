        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isAvailable ? () => context.push('/books/${item.book.id}') : null,
            child: Opacity(
              opacity: isAvailable ? 1.0 : 0.45,
              child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              child: Row(
                children: [
                  ClipRRect(