// lib/features/auth/view/forgot_password_page.dart
//
// Heritage redesign (Auth Phase 1, screens 2c/2d). SheikhyAuthHeader band +
// persistent info/danger SheikhyNotice + email field + primary CTA.
// Server errors flip the notice to danger and mark the field red (design 2d).
//
// Visual-only migration: AuthCubit contract is unchanged — resetPassword(email)
// → AuthPasswordResetSent → pushReplacement('/reset-sent'). No Bloc/Cubit/
// Repository touched.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/insets.dart';
import '../../../core/widgets/sheikhy_auth_header.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../core/widgets/sheikhy_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  String? _formError;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();

    String? emailError;
    if (email.isEmpty) {
      emailError = 'أدخل بريدك الإلكتروني';
    } else if (!email.contains('@')) {
      emailError = 'صيغة البريد غير صحيحة';
    }

    setState(() {
      _formError = null;
      _emailError = emailError;
    });

    if (emailError != null) return;

    context.read<AuthCubit>().resetPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() {
            _formError = state.message;
            _emailError = 'البريد غير مسجّل لدينا';
          });
        } else if (state is AuthPasswordResetSent) {
          if (!mounted) return;
          context.pushReplacement('/reset-sent', extra: state.email);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            SheikhyAuthHeader(
              title: 'استعادة كلمة المرور',
              subtitle: 'نرسل لك رمز تحقق على بريدك',
              onBack: () => context.pop(),
              backLabel: 'رجوع',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s5,
                  AppSpacing.pageGutter,
                  AppSpacing.s5 + context.safeBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SheikhyNotice(
                      message:
                          _formError ??
                          'أدخل البريد المسجّل، وسيصلك رمز صالح لعشر دقائق',
                      variant: _formError != null
                          ? SheikhyNoticeVariant.danger
                          : SheikhyNoticeVariant.info,
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    SheikhyTextField(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      hintText: 'talib@sheikhy.app',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.mail_outline),
                      textInputAction: TextInputAction.done,
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null || _formError != null) {
                          setState(() {
                            _emailError = null;
                            _formError = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    BlocBuilder<AuthCubit, AuthState>(
                      buildWhen: (prev, curr) =>
                          curr is AuthLoading || prev is AuthLoading,
                      builder: (context, state) {
                        return SheikhyButton.primary(
                          label: 'أرسل رمز التحقق',
                          fullWidth: true,
                          isLoading: state is AuthLoading,
                          onPressed: _submit,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _BackToLoginFooter(onTap: () => context.pop()),
                    SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToLoginFooter extends StatelessWidget {
  const _BackToLoginFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'تذكرتها؟ ',
          style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
        ),
        InkWell(
          onTap: onTap,
          child: Text(
            'عد لتسجيل الدخول',
            style: AppTextStyles.small.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
