// lib/features/auth/view/login_page.dart
//
// Heritage redesign (Auth Phase 1, screens 1b/1c). Header band + email +
// password (with eye toggle + inline "نسيتها؟") + "remember me" + primary CTA +
// "أو" divider + alternate sign-in + sign-up footer. Server/validation errors
// surface as a top SheikhyNotice banner (design 1c) plus per-field errorText.
//
// Visual-only migration: the AuthCubit contract is unchanged — signIn(email,
// password). "remember me" and "الدخول برمز الملفة" are rendered but not yet
// wired (no backing cubit method) per the approved plan.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_auth_header.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_checkbox.dart';
import '../../../core/widgets/sheikhy_labeled_divider.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../core/widgets/sheikhy_password_field.dart';
import '../../../core/widgets/sheikhy_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  String? _formError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    String? passwordError;
    if (email.isEmpty) {
      emailError = 'أدخل بريدك الإلكتروني';
    } else if (!email.contains('@')) {
      emailError = 'صيغة البريد غير صحيحة';
    }
    if (password.isEmpty) {
      passwordError = 'أدخل كلمة المرور';
    }

    setState(() {
      _formError = null;
      _emailError = emailError;
      _passwordError = passwordError;
    });

    if (emailError != null || passwordError != null) return;
    context.read<AuthCubit>().signIn(email: email, password: password);
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هذه الميزة قيد التطوير'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => curr is AuthError,
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _formError = state.message);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            const SheikhyAuthHeader(
              title: 'أهلاً بعودتك',
              subtitle: 'أكمل ما بدأته في مجالس العلم',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.pageGutter,
                  AppSpacing.s6,
                  AppSpacing.pageGutter,
                  AppSpacing.s5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_formError != null) ...[
                      SheikhyNotice(message: _formError!),
                      const SizedBox(height: AppSpacing.s5),
                    ],
                    SheikhyTextField(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      hintText: 'example@domain.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.mail_outline),
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _PasswordWithForgot(
                      controller: _passwordController,
                      errorText: _passwordError,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      onForgot: () => context.push('/forgot-password'),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SheikhyCheckbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v),
                      label: Text(
                        'ابقني مسجّلاً في هذا الجهاز',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    BlocBuilder<AuthCubit, AuthState>(
                      buildWhen: (prev, curr) =>
                          curr is AuthLoading || prev is AuthLoading,
                      builder: (context, state) {
                        return SheikhyButton.primary(
                          label: 'دخول',
                          fullWidth: true,
                          isLoading: state is AuthLoading,
                          onPressed: _submit,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    const SheikhyLabeledDivider(label: 'أو'),
                    const SizedBox(height: AppSpacing.s5),
                    SheikhyButton.secondary(
                      label: 'الدخول برمز الملفة',
                      fullWidth: true,
                      onPressed: _comingSoon,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _SignupFooter(onTap: () => context.push('/signup')),
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

/// Password field with the "نسيتها؟" link overlaid on its label line (the
/// heritage fields bake in their own label, so the link is positioned over it).
class _PasswordWithForgot extends StatelessWidget {
  const _PasswordWithForgot({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onForgot,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onForgot;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SheikhyPasswordField(
          label: 'كلمة المرور',
          controller: controller,
          errorText: errorText,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: InkWell(
            onTap: onForgot,
            child: Text(
              'نسيتها؟',
              style: AppTextStyles.small.copyWith(
                color: AppColors.goldDeep,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.goldLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupFooter extends StatelessWidget {
  const _SignupFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟ ',
          style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
        ),
        InkWell(
          onTap: onTap,
          child: Text(
            'أنشئ حسابًا',
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
