// lib/features/practice/view/practice_loading_page.dart
import 'dart:math';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/girih_background.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../models/quiz_question_entity.dart';
import '../data/practice_repository.dart';
import '../logic/practice_exam_builder.dart';
import '../logic/practice_exam_config.dart';

/// Seeded defaults, used when no active quotes exist or the fetch fails.
/// Mirrors the rows seeded in migration 0020.
const List<({String text, String source})> _defaultQuotes = [
  (
    text: '«مَن يُرِدِ اللهُ بِهِ خَيْرًا يُفَقِّهْهُ فِي الدِّينِ»',
    source: 'متفق عليه',
  ),
  (
    text: '﴿وَأَعِدُّوا لَهُم مَّا اسْتَطَعْتُم مِّن قُوَّةٍ﴾',
    source: 'الأنفال: 60',
  ),
  (
    text: '﴿إِنَّمَا يَخْشَى اللَّهَ مِنْ عِبَادِهِ الْعُلَمَاءُ﴾',
    source: 'فاطر: 28',
  ),
];

/// Pre-exam splash: cycles motivational quotes (~3s each) with a progress bar
/// while the question pool is prefetched in the background, so the exam opens
/// instantly. «ابدأ الآن» appears after the first quote and lets the student
/// skip ahead.
class PracticeLoadingPage extends StatefulWidget {
  final PracticeExamConfig config;
  const PracticeLoadingPage({super.key, required this.config});

  @override
  State<PracticeLoadingPage> createState() => _PracticeLoadingPageState();
}

class _PracticeLoadingPageState extends State<PracticeLoadingPage>
    with SingleTickerProviderStateMixin {
  static const _perQuote = Duration(seconds: 3);

  late final AnimationController _controller;
  List<({String text, String source})> _quotes = _defaultQuotes;
  int _index = 0;
  bool _navigated = false;
  bool _showSkip = false;

  /// Set once the quotes are done but the pool isn't ready yet — the progress
  /// bar goes indeterminate until the prefetch resolves.
  bool _waitingForPool = false;

  late final Future<Either<Failure, List<QuizQuestionEntity>>> _prepFuture;
  Either<Failure, List<QuizQuestionEntity>>? _prepResult;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _perQuote)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onQuoteDone();
      });
    _controller.forward();
    _loadQuotes();
    _startPrefetch();
  }

  void _startPrefetch() {
    _prepFuture = buildPracticeExam(
      context.read<PracticeRepository>(),
      widget.config,
      Random(),
    );
    _prepFuture.then((result) {
      if (!mounted) return;
      _prepResult = result;
      if (_waitingForPool) _navigate();
    });
  }

  Future<void> _loadQuotes() async {
    final result = await context.read<PracticeRepository>().getLoadingQuotes();
    if (!mounted) return;
    result.fold((_) {}, (quotes) {
      if (quotes.isEmpty) return;
      setState(() {
        _quotes = [
          for (final q in quotes) (text: q.text, source: q.source ?? ''),
        ];
        if (_index >= _quotes.length) _index = 0;
      });
    });
  }

  void _onQuoteDone() {
    if (!_showSkip) setState(() => _showSkip = true);
    if (_index < _quotes.length - 1) {
      setState(() => _index++);
      _controller.forward(from: 0);
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_prepResult != null) {
      _navigate();
    } else {
      setState(() => _waitingForPool = true); // bar goes indeterminate
    }
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    setState(() => _navigated = true);
    final prebuilt = _prepResult?.fold((_) => null, (qs) => qs);
    // Push (not replace) so the exam sits above this splash; when the exam
    // flow pops, pop this splash too so control returns to the setup tab
    // (which then reloads history). Back from the result therefore lands on
    // the اختبر نفسك tab, never on this splash or the exam.
    await context.push(
      '/practice/exam',
      extra: PracticeExamLaunch(widget.config, prebuilt),
    );
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once handed off to the exam, this splash is covered; if it's briefly
    // revealed while popping back to setup, show a plain branded frame rather
    // than flashing the quotes again.
    if (_navigated) {
      return ColoredBox(
        color: AppColors.primary,
        child: const SizedBox.expand(),
      );
    }

    final quote = _quotes[_index];
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          Positioned.fill(
            child: GirihBackground(color: AppColors.goldLight, opacity: 0.12),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pageGutter),
              child: Column(
                children: [
                  const Spacer(),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _QuoteCard(
                          key: ValueKey(_index),
                          text: quote.text,
                          source: quote.source,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => ClipRRect(
                      borderRadius: AppRadii.rPill,
                      child: LinearProgressIndicator(
                        value: _waitingForPool ? null : _controller.value,
                        minHeight: 6,
                        backgroundColor: AppColors.inkInvert.withValues(
                          alpha: 0.25,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.goldLight,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.s4 + context.safeBottom),
                  if (_waitingForPool)
                    Text(
                      'جارٍ تجهيز الاختبار…',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.goldLight,
                      ),
                    )
                  else if (_showSkip)
                    SheikhyButton.gold(
                      fullWidth: true,
                      label: 'ابدأ الآن',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: _navigate,
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String text;
  final String source;
  const _QuoteCard({super.key, required this.text, required this.source});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(
            color: AppColors.inkInvert,
            height: 1.8,
          ),
        ),
        if (source.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            source,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.goldLight),
          ),
        ],
      ],
    );
  }
}
