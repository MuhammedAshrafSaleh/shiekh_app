// lib/features/qa/view/my_questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/account_gate.dart';
import '../../../core/widgets/sheikhy_empty_state.dart';
import '../../../core/widgets/sheikhy_error_state.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/my_questions_cubit.dart';
import '../cubit/my_questions_state.dart';
import '../widgets/question_card.dart';

class MyQuestionsPage extends StatelessWidget {
  const MyQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SheikhyPageHeader(title: 'أسئلتي', showBack: true),
          Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    // "أسئلتي" is account-only — a guest has none. Gate before the list so a
    // guest reaching this page (e.g. via the profile menu) sees the prompt
    // rather than a confusing empty state.
    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;
    if (isGuest) {
      return const AccountGate(
        reason: GateReason.account,
        returnTo: '/my-questions',
        guestMessage: 'أنشئ حساباً لعرض أسئلتك',
      );
    }

    return BlocBuilder<MyQuestionsCubit, MyQuestionsState>(
      builder: (context, state) {
        return switch (state) {
          MyQuestionsInitial() || MyQuestionsLoading() => const _LoadingView(),
          MyQuestionsError(:final message) => SheikhyErrorState(
              heading: 'تعذّر تحميل الأسئلة',
              message: message,
              onRetry: () =>
                  context.read<MyQuestionsCubit>().loadMyQuestions(),
            ),
          MyQuestionsEmpty() => const SheikhyEmptyState(
              icon: Icons.question_answer_outlined,
              heading: 'لا توجد أسئلة بعد',
              subtitle: 'يمكنك طرح سؤالك من صفحة الكتاب.',
            ),
          MyQuestionsLoaded(:final questions) => RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () =>
                  context.read<MyQuestionsCubit>().loadMyQuestions(),
              child: ListView.separated(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s3,
                  AppSpacing.pageGutter,
                  AppSpacing.s7 + context.safeBottom,
                ),
                itemCount: questions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s3),
                itemBuilder: (_, index) =>
                    QuestionCard(question: questions[index]),
              ),
            ),
          _ => const SizedBox.shrink(),
        };
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
          const Text('جار تحميل الأسئلة...'),
        ],
      ),
    );
  }
}
