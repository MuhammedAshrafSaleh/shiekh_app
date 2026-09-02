// lib/features/home/widgets/featured_book_card.dart
//
// Thin wrapper: maps BookWithProgressEntity to SheikhyHorizontalBookCard.
import 'package:flutter/material.dart';

import '../../../core/widgets/sheikhy_horizontal_book_card.dart';
import '../../../models/book_with_progress_entity.dart';

class FeaturedBookCard extends StatelessWidget {
  const FeaturedBookCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final BookWithProgressEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SheikhyHorizontalBookCard(
      title: item.book.title,
      totalLessons: item.totalLessons,
      completedLessons: item.completedLessons,
      progress: item.progress,
      coverImageUrl: item.book.coverImageUrl,
      isEnrolled: item.isEnrolled,
      onTap: onTap,
    );
  }
}
