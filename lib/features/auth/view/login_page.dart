// lib/features/auth/view/login_page.dart
//
// Heritage redesign (Auth Phase 1, screens 1b/1c). Header band + email +
// password (with eye toggle + inline "نسيتها؟") + "remember me" + primary CTA +
// "أو" divider + guest entry ("تصفح كزائر") + sign-up footer. Server/validation
// errors surface as a top SheikhyNotice banner (design 1c) plus per-field
// errorText.
//
// Visual-only migration: the AuthCubit contract is unchanged — signIn(email,
// password). "remember me" is rendered but not yet wired (no backing cubit
// method) per the approved plan. The guest button calls continueAsGuest().
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
import '../pending_conversion.dart';

class LoginPage extends StatefulWidget {
  /// Set when arriving from the guest email-collision path: after signing into
  /// the pre-existing account, auto-enroll in [autoEnrollBookId] and return to
  /// [returnTo]. Both null for a normal login.
  final String? returnTo;
  final String? autoEnrollBookId;

  /// Reason banner to show, set by a redirect (e.g. 'email_exists' when a guest
  /// tried to convert to an already-registered email).
  final String? notice;

  const LoginPage({
    super.key,
    this.returnTo,
    this.autoEnrollBookId,
    this.notice,
  });

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

  bool get _hasPendingReturn =>
      (widget.returnTo != null && widget.returnTo!.isNotEmpty) ||
      (widget.autoEnrollBookId != null &&
          widget.autoEnrollBookId!.isNotEmpty);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    // Collision sign-in from a gate: persist the return intent so the durable
    // app-level auth listener finishes (enroll + return) after sign-in.
    if (_hasPendingReturn) {
      await PendingConversion.save(
        returnTo: widget.returnTo,
        autoEnrollBookId: widget.autoEnrollBookId,
      );
      if (!mounted) return;
    }
    context.read<AuthCubit>().signIn(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthError || curr is AuthAuthenticated,
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _formError = state.message);
        } else if (state is AuthAuthenticated &&
            state.isGuest &&
            !_hasPendingReturn) {
          // "تصفح كزائر" from the login screen. The router keeps authenticated
          // guests on conversion screens (login/signup) for the in-place
          // conversion flow, so it won't auto-route this fresh guest — navigate
          // to /home explicitly.
          context.go('/home');
        }
        // Collision sign-in success (AuthAuthenticated, non-guest) is finished by
        // the durable app-level auth listener (app.dart) via the persisted
        // PendingConversion intent.
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        resizeToAvoidBottomInset: true,
        // The heritage fields draw their own cream container; neutralize the
        // still-legacy global inputDecorationTheme (filled: true, white fill)
        // so it doesn't bleed a white block inside them. Interim fix until the
        // heritage theme is wired globally (see review note / MIGRATION_NOTES).
        body: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: false,
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          child: Column(
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
                    if (widget.notice == 'email_exists') ...[
                      SheikhyNotice(
                        variant: SheikhyNoticeVariant.info,
                        message:
                            'هذا البريد الإلكتروني مسجّل مسبقاً. سجّل الدخول للمتابعة إلى حيث توقفت.',
                      ),
                      const SizedBox(height: AppSpacing.s5),
                    ],
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
                          curr is AuthLoading ||
                          prev is AuthLoading,
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
                    // Guest entry point — mirrors the onboarding "متابعة كزائر"
                    // path for users who skip onboarding or return to the app.
                    // Starts an anonymous session; the auth-state change routes
                    // the guest to /home.
                    SheikhyButton.secondary(
                      label: 'تصفح كزائر',
                      fullWidth: true,
                      onPressed: () =>
                          context.read<AuthCubit>().continueAsGuest(),
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
