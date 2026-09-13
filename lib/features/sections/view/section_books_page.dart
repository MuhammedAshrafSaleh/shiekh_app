// lib/features/sections/view/section_books_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_badge.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../core/widgets/sheikhy_progress_bar.dart';
import '../../../core/widgets/sheikhy_search_field.dart';
import '../../../models/book_with_progress_entity.dart';
import '../cubit/section_books_cubit.dart';
import '../cubit/section_books_state.dart';

class SectionBooksPage extends StatefulWidget {
  const SectionBooksPage({
    super.key,
    required this.sectionId,
    this.sectionName,
  });

  final String sectionId;
  final String? sectionName;

  @override
  State<SectionBooksPage> createState() => _SectionBooksPageState();
}

class _SectionBooksPageState extends State<SectionBooksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookWithProgressEntity> _filter(List<BookWithProgressEntity> books) {
    if (_query.isEmpty) return books;
    return books.where((b) => b.book.title.contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.sectionName?.isNotEmpty == true
        ? widget.sectionName!
        : 'كتب القسم';

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheikhyPageHeader(title: title, showBack: true),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.pageGutter,
              AppSpacing.s4,
              AppSpacing.pageGutter,
              AppSpacing.s3,
            ),
            child: SheikhySearchField(
              controller: _searchController,
              hintText: 'بحث في الكتب...',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _Body(sectionId: widget.sectionId, filter: _filter),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.sectionId, required this.filter});

  final String sectionId;
  final List<BookWithProgressEntity> Function(List<BookWithProgressEntity>)
  filter;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SectionBooksCubit, SectionBooksState>(
      builder: (context, state) {
        if (state is SectionBooksInitial || state is SectionBooksLoading) {
          return const _LoadingView();
        }
        if (state is SectionBooksError) {
          return SheikhyErrorState(
            heading: 'تعذّر تحميل الكتب',
            message: state.message,
            onRetry: () =>
                context.read<SectionBooksCubit>().loadBooks(sectionId),
          );
        }
        if (state is SectionBooksEmpty) {
          return const SheikhyEmptyState(
            icon: Icons.menu_book_outlined,
            heading: 'لا توجد كتب بعد',
            subtitle: 'لم تُضَف كتب لهذا القسم بعد.',
          );
        }
        if (state is SectionBooksLoaded) {
          return _LoadedView(
            state: state,
            sectionId: sectionId,
            filter: filter,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('جار تحميل المحتوى...', style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.sectionId,
    required this.filter,
  });

  final SectionBooksLoaded state;
  final String sectionId;
  final List<BookWithProgressEntity> Function(List<BookWithProgressEntity>)
  filter;

  @override
  Widget build(BuildContext context) {
    final filtered = filter(state.books);

    if (filtered.isEmpty) {
      return const SheikhyEmptyState(
        icon: Icons.search_off_outlined,
        heading: 'لا توجد نتائج',
        subtitle: 'جرّب كلمة بحث مختلفة.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => context.read<SectionBooksCubit>().loadBooks(sectionId),
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.pageGutter,
          AppSpacing.s1,
          AppSpacing.pageGutter,
          AppSpacing.s7,
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
        itemBuilder: (context, index) => _BookListItem(item: filtered[index]),
      ),
    );
  }
}

// ── Book list item ────────────────────────────────────────────────────────────

class _BookListItem extends StatelessWidget {
  const _BookListItem({required this.item});

  final BookWithProgressEntity item;

  String _toArabic(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final hasProgress = item.isEnrolled && item.totalLessons > 0;
    final pct = (item.progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.rLg,
          onTap: () => context.push('/books/${book.id}'),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cover(title: book.title, imageUrl: book.coverImageUrl),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: _Info(
                    item: item,
                    hasProgress: hasProgress,
                    pct: pct,
                    toArabic: _toArabic,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: AppSpacing.s2),
                  child: Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.rMd,
      child: SizedBox(
        width: 56,
        height: 76,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _CoverPlaceholder(title: title),
                errorWidget: (_, _, _) => _CoverPlaceholder(title: title),
              )
            : _CoverPlaceholder(title: title),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title.characters.first : '؟',
        style: GoogleFonts.reemKufi(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.inkInvert,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.item,
    required this.hasProgress,
    required this.pct,
    required this.toArabic,
  });

  final BookWithProgressEntity item;
  final bool hasProgress;
  final int pct;
  final String Function(int) toArabic;

  @override
  Widget build(BuildContext context) {
    final book = item.book;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          book.title,
          style: GoogleFonts.arefRuqaa(
            fontSize: 19,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: AppColors.ink,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (book.description != null && book.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            book.description!,
            style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        if (hasProgress) ...[
          SheikhyProgressBar(value: item.progress),
          const SizedBox(height: AppSpacing.s1),
          Text(
            '${toArabic(pct)}٪ • ${toArabic(item.completedLessons)} من ${toArabic(item.totalLessons)} درساً',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0,
            ),
          ),
        ] else ...[
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 14,
                color: AppColors.inkFaint,
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                item.totalLessons > 0
                    ? '${toArabic(item.totalLessons)} دروس'
                    : 'ابدأ',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkFaint,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              const SheikhyBadge(
                variant: SheikhyBadgeVariant.certified,
                label: 'ابدأ التعلّم',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
