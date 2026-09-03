// lib/features/exam/view/exam_result_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_labeled_divider.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../models/certificate_entity.dart';
import '../bloc/exam_state.dart';
import '../data/exam_repository.dart';
import '../widgets/exam_review_list.dart';

class ExamResultPage extends StatefulWidget {
  final ExamCompleted examCompleted;

  const ExamResultPage({super.key, required this.examCompleted});

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  List<ExamReviewQuestion>? _reviewQuestions;
  bool _reviewLoading = true;
  bool _reviewFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchReview();
  }

  Future<void> _fetchReview() async {
    setState(() {
      _reviewLoading = true;
      _reviewFailed = false;
    });

    final result = await context.read<ExamRepository>().getExamReview(
          widget.examCompleted.bookId,
          widget.examCompleted.result.attemptId,
        );

    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _reviewLoading = false;
        _reviewFailed = true;
      }),
      (questions) => setState(() {
        _reviewQuestions = questions;
        _reviewLoading = false;
      }),
    );
  }

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.examCompleted.result;
    final passed = result.passed;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheikhyPageHeader(
            title: 'نتائج الاختبار',
            showBack: false,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.pageGutter,
                AppSpacing.s6,
                AppSpacing.pageGutter,
                AppSpacing.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Score ring ─────────────────────────────────────────
                  Center(child: _ScoreRing(score: result.score, passed: passed)),
                  const SizedBox(height: AppSpacing.s5),

                  // ── Pass / Fail heading ────────────────────────────────
                  Text(
                    passed ? 'تهانينا! لقد نجحت' : 'لم تنجح هذه المرة',
                    style: GoogleFonts.arefRuqaa(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    passed
                        ? 'لقد أتممت الاختبار بنجاح وتفوّق.'
                        : 'لم تبلغ النسبة المطلوبة. يمكنك المحاولة مرة أخرى.',
                    style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s4),

                  // ── Score pill ─────────────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.s5,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.rPill,
                        border: Border.all(
                          color: AppColors.border,
                          width: AppBorders.hairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_ar(result.correct)} من ${_ar(result.total)} إجابة صحيحة',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Icon(
                            passed
                                ? Icons.check_circle_outline_rounded
                                : Icons.highlight_off_rounded,
                            size: 18,
                            color: passed ? AppColors.success : AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Certificate preview (pass only) ────────────────────
                  if (passed) ...[
                    const SizedBox(height: AppSpacing.s5),
                    Text(
                      'معاينة الشهادة',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    _CertPreviewCard(result: result),
                  ],

                  const SizedBox(height: AppSpacing.s5),

                  // ── Action buttons ─────────────────────────────────────
                  if (passed)
                    SheikhyButton.primary(
                      fullWidth: true,
                      label: 'تحميل الشهادة',
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () {
                        final cert = CertificateEntity(
                          id: '',
                          userId: '',
                          bookId: widget.examCompleted.bookId,
                          finalExamAttemptId: result.attemptId,
                          finalScore: result.score,
                          gradeLabel: result.gradeLabel.isEmpty
                              ? null
                              : result.gradeLabel,
                          issuedAt: DateTime.now(),
                        );
                        context.push(
                          '/certificates/${widget.examCompleted.bookId}',
                          extra: cert,
                        );
                      },
                    ),
                  if (passed) const SizedBox(height: AppSpacing.s3),
                  SheikhyButton.secondary(
                    fullWidth: true,
                    label: 'العودة للكتاب',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () =>
                        context.go('/books/${widget.examCompleted.bookId}'),
                  ),

                  // ── Answer review ──────────────────────────────────────
                  const SizedBox(height: AppSpacing.s6),
                  const SheikhyLabeledDivider(label: 'مراجعة الإجابات'),
                  const SizedBox(height: AppSpacing.s4),

                  if (_reviewLoading)
                    Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  else if (_reviewFailed)
                    Center(
                      child: SheikhyButton.text(
                        label: 'فشل تحميل المراجعة — إعادة المحاولة',
                        onPressed: _fetchReview,
                      ),
                    )
                  else if (_reviewQuestions != null)
                    ExamReviewList(questions: _reviewQuestions!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score ring ───────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final int score;
  final bool passed;

  const _ScoreRing({required this.score, required this.passed});

  static String _ar(int n) {
    const w = '0123456789';
    const a = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = w.indexOf(c);
      return i >= 0 ? a[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = passed ? AppColors.primary : AppColors.danger;

    return Container(
      width: 172,
      height: 172,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 10),
        color: AppColors.paper,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '٪${_ar(score)}',
            style: GoogleFonts.arefRuqaa(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'النتيجة النهائية',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Certificate preview card ─────────────────────────────────────────────────

class _CertPreviewCard extends StatelessWidget {
  final ExamSubmitResult result;

  const _CertPreviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMMM yyyy', 'ar').format(DateTime.now());

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.gold, width: AppBorders.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Shield icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.gold,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),

          // Subtitle
          Text(
            'لإتمامه بنجاح دراسة واختبار',
            style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),

          // Grade label (if available)
          if (result.gradeLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              result.gradeLabel,
              style: GoogleFonts.arefRuqaa(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: AppColors.goldDeep,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: AppSpacing.s4),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s3),

          // Grade + Date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CertMeta(label: 'التقدير', value: result.gradeLabel),
              _CertMeta(
                label: 'التاريخ',
                value: dateStr,
                align: TextAlign.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CertMeta extends StatelessWidget {
  final String label;
  final String value;
  final TextAlign align;

  const _CertMeta({
    required this.label,
    required this.value,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.inkFaint),
        ),
        Text(
          value,
          style: AppTextStyles.small.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
          textAlign: align,
        ),
      ],
    );
  }
}
