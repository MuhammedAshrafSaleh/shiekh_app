// lib/features/admin/onboarding/view/admin_onboarding_page.dart
//
// Admin management for onboarding slides: inline edit main/sub text, toggle
// active, and reorder. No add/delete (the 3 seed slides are the base set).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sheikhy_button.dart';
import '../../../../core/widgets/sheikhy_text_field.dart';
import '../../../../models/onboarding_slide_entity.dart';
import '../cubit/admin_onboarding_cubit.dart';
import '../cubit/admin_onboarding_state.dart';

class AdminOnboardingPage extends StatelessWidget {
  const AdminOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شاشات الترحيب')),
      body: BlocConsumer<AdminOnboardingCubit, AdminOnboardingState>(
        listenWhen: (prev, curr) =>
            curr is AdminOnboardingActionSuccess ||
            curr is AdminOnboardingError,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state is AdminOnboardingActionSuccess) {
            messenger.showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ));
          } else if (state is AdminOnboardingError) {
            messenger.showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ));
          }
        },
        buildWhen: (prev, curr) => curr is! AdminOnboardingActionSuccess,
        builder: (context, state) {
          if (state is AdminOnboardingLoading ||
              state is AdminOnboardingInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminOnboardingError) {
            return _ErrorView(message: state.message);
          }
          if (state is AdminOnboardingLoaded) {
            if (state.slides.isEmpty) {
              return const Center(child: Text('لا توجد شاشات ترحيب'));
            }
            return _SlidesList(slides: state.slides);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SlidesList extends StatelessWidget {
  const _SlidesList({required this.slides});

  final List<OnboardingSlideEntity> slides;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminOnboardingCubit>();
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s4),
      itemCount: slides.length,
      onReorder: cubit.reorder,
      itemBuilder: (context, index) {
        final slide = slides[index];
        return _SlideEditorCard(
          key: ValueKey(slide.id),
          slide: slide,
          index: index,
        );
      },
    );
  }
}

class _SlideEditorCard extends StatefulWidget {
  const _SlideEditorCard({
    super.key,
    required this.slide,
    required this.index,
  });

  final OnboardingSlideEntity slide;
  final int index;

  @override
  State<_SlideEditorCard> createState() => _SlideEditorCardState();
}

class _SlideEditorCardState extends State<_SlideEditorCard> {
  late final TextEditingController _mainController;
  late final TextEditingController _subController;

  @override
  void initState() {
    super.initState();
    _mainController = TextEditingController(text: widget.slide.mainText);
    _subController = TextEditingController(text: widget.slide.subText ?? '');
  }

  @override
  void dispose() {
    _mainController.dispose();
    _subController.dispose();
    super.dispose();
  }

  void _save() {
    final main = _mainController.text.trim();
    if (main.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('النص الأساسي مطلوب'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    context.read<AdminOnboardingCubit>().save(
          id: widget.slide.id,
          mainText: main,
          subText: _subController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.slide.isHadith ? 'حديث' : 'عادي';
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.s4),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle,
                      color: AppColors.inkFaint),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'شاشة ${widget.index + 1} · $typeLabel',
                  style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
                ),
                const Spacer(),
                Text(
                  widget.slide.isActive ? 'مفعّلة' : 'مخفية',
                  style: AppTextStyles.caption.copyWith(
                    color: widget.slide.isActive
                        ? AppColors.success
                        : AppColors.inkFaint,
                  ),
                ),
                Switch(
                  value: widget.slide.isActive,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) =>
                      context.read<AdminOnboardingCubit>().toggleActive(
                            id: widget.slide.id,
                            isActive: v,
                          ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            SheikhyTextField(
              label: 'النص الأساسي',
              controller: _mainController,
            ),
            const SizedBox(height: AppSpacing.s3),
            SheikhyTextField(
              label: 'النص التوضيحي (اختياري)',
              controller: _subController,
            ),
            const SizedBox(height: AppSpacing.s3),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SheikhyButton.primary(
                label: 'حفظ',
                size: SheikhyButtonSize.sm,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.s5),
          SheikhyButton.secondary(
            label: 'إعادة المحاولة',
            onPressed: () => context.read<AdminOnboardingCubit>().load(),
          ),
        ],
      ),
    );
  }
}
