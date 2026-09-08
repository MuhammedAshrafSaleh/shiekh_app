// lib/features/auth/view/signup_page.dart
//
// Heritage redesign (Auth Phase 1, screens 2a/2b). SheikhyAuthHeader band +
// four fields (name / email / password + strength meter / confirm) + terms
// checkbox + primary CTA. Server errors surface as a top SheikhyNotice banner
// (design 2b); per-field client errors as errorText on each field.
//
// Visual-only migration: AuthCubit contract is unchanged — signUp(email,
// password, fullName). No Bloc/Cubit/Repository touched.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_auth_header.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_checkbox.dart';
import '../../../core/widgets/sheikhy_notice.dart';
import '../../../core/widgets/sheikhy_password_field.dart';
import '../../../core/widgets/sheikhy_password_strength.dart';
import '../../../core/widgets/sheikhy_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../post_auth_flow.dart';

// The mapped collision message from AuthRepository._mapAuthError — used to
// detect "this email already belongs to another account" and offer sign-in.
const String _kEmailTakenMsg = 'هذا البريد الإلكتروني مسجّل مسبقاً';

// Pragmatic email-shape check (local@domain.tld). Applied identically to a
// normal signup and an in-place guest conversion so a malformed address is
// rejected on the client before any signUp/convertGuest call reaches Supabase.
final RegExp _kEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class SignupPage extends StatefulWidget {
  /// When launched from a guest gate: where to return after account creation,
  /// and which book to auto-enroll in. Both null for a normal (non-guest) signup.
  final String? returnTo;
  final String? autoEnrollBookId;

  const SignupPage({super.key, this.returnTo, this.autoEnrollBookId});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _password = '';
  bool _termsAccepted = false;

  // Guest-conversion bookkeeping: set true when this submit upgrades an
  // anonymous session in place; guards the one-shot post-auth navigation.
  bool _isConversion = false;
  bool _postAuthHandled = false;

  String? _formError;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _strengthHint(String pw) {
    if (pw.isEmpty) return null;
    final score = _score(pw);
    if (score <= 1) return 'ضعيفة';
    if (score == 2) return 'مقبولة';
    if (score == 3) return 'قوة جيدة • 8 محارف فأكثر مع رقم';
    return 'ممتازة';
  }

  // Mirrors SheikhyPasswordStrength._score so the hint matches the meter.
  int _score(String pw) {
    var s = 0;
    if (pw.length >= 8) s++;
    if (RegExp(r'\d').hasMatch(pw)) s++;
    if (RegExp(r'[A-Za-zء-ي]').hasMatch(pw)) s++;
    if (pw.length >= 12 || RegExp(r'[^A-Za-z0-9ء-ي]').hasMatch(pw)) s++;
    return s.clamp(0, 4);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? nameError;
    String? emailError;
    String? passwordError;
    String? confirmError;
    String? formError;

    if (name.isEmpty) {
      nameError = 'أدخل اسمك الكامل';
    } else if (name.length < 3) {
      nameError = 'الاسم قصير جداً';
    }

    if (email.isEmpty) {
      emailError = 'أدخل بريدك الإلكتروني';
    } else if (!_kEmailRegex.hasMatch(email)) {
      emailError = 'صيغة البريد غير صحيحة';
    }

    if (password.isEmpty) {
      passwordError = 'أدخل كلمة المرور';
    } else if (password.length < 6) {
      passwordError = 'كلمة المرور قصيرة جداً';
    }

    if (confirm.isEmpty) {
      confirmError = 'أكد كلمة المرور';
    } else if (confirm != password) {
      confirmError = 'الكلمتان غير متطابقتين';
    }

    if (!_termsAccepted) {
      formError = 'يجب الموافقة على شروط الانتفاع أولاً';
    }

    setState(() {
      _formError = formError;
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null ||
        formError != null) {
      return;
    }

    // If the current session is a guest, upgrade it IN PLACE (same auth.uid)
    // instead of creating a second account.
    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;
    _isConversion = isGuest;

    if (isGuest) {
      context.read<AuthCubit>().convertGuest(
        email: email,
        password: password,
        fullName: name,
      );
    } else {
      context.read<AuthCubit>().signUp(
        email: email,
        password: password,
        fullName: name,
      );
    }
  }

  /// Collision: the email already belongs to a different account. We cannot
  /// merge, so offer to sign into that account — preserving returnTo/autoEnroll
  /// so the journey still ends on the intended lesson.
  void _promptSignInInstead() {
    final loginLoc = Uri(
      path: '/login',
      queryParameters: {
        if (widget.returnTo != null) 'returnTo': widget.returnTo,
        if (widget.autoEnrollBookId != null)
          'autoEnrollBookId': widget.autoEnrollBookId,
      },
    ).toString();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
        title: Text(
          'البريد مسجّل مسبقاً',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هذا البريد لديه حساب بالفعل. سجّل الدخول للمتابعة إلى الدرس.',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SheikhyButton.secondary(
            label: 'إلغاء',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          SheikhyButton.primary(
            label: 'تسجيل الدخول',
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.go(loginLoc);
            },
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(String email) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
        title: Text(
          'تحقق من بريدك الإلكتروني',
          style: AppTextStyles.h3.copyWith(color: AppColors.ink),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'تم إرسال رابط التأكيد إلى\n$email\n\nافتح بريدك واضغط على الرابط لتفعيل حسابك.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.inkMuted,
            height: 1.7,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SheikhyButton.primary(
            label: 'حسناً',
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _formError = state.message);
          // Guest conversion hit an already-registered email → offer sign-in.
          if (_isConversion && state.message == _kEmailTakenMsg) {
            _promptSignInInstead();
          }
        } else if (state is AuthEmailConfirmationRequired) {
          if (!mounted) return;
          _showConfirmationDialog(_emailController.text.trim());
        } else if (state is AuthAuthenticated &&
            !state.isGuest &&
            _isConversion &&
            !_postAuthHandled) {
          // Conversion succeeded: enroll in the gated book and return to the
          // exact lesson the guest was blocked on.
          _postAuthHandled = true;
          completeGuestReturn(
            context,
            returnTo: widget.returnTo,
            enrollBookId: widget.autoEnrollBookId,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            SheikhyAuthHeader(
              title: 'انضمّ إلى المجلس',
              subtitle: 'أنشئ حسابك لتتابع المتون والاختبارات',
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
                      label: 'الاسم الكامل',
                      controller: _nameController,
                      hintText: 'أحمد بن سالم',
                      prefixIcon: const Icon(Icons.person_outline),
                      textInputAction: TextInputAction.next,
                      errorText: _nameError,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SheikhyTextField(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      hintText: 'talib@sheikhy.app',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.mail_outline),
                      textInputAction: TextInputAction.next,
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SheikhyPasswordField(
                      label: 'كلمة المرور',
                      controller: _passwordController,
                      textInputAction: TextInputAction.next,
                      errorText: _passwordError,
                      onChanged: (v) {
                        setState(() {
                          _password = v;
                          if (_passwordError != null) _passwordError = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    SheikhyPasswordStrength(
                      password: _password,
                      hintText: _strengthHint(_password),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SheikhyPasswordField(
                      label: 'تأكيد كلمة المرور',
                      controller: _confirmController,
                      textInputAction: TextInputAction.done,
                      errorText: _confirmError,
                      onChanged: (_) {
                        if (_confirmError != null) {
                          setState(() => _confirmError = null);
                        }
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SheikhyCheckbox(
                      value: _termsAccepted,
                      onChanged: (v) {
                        setState(() {
                          _termsAccepted = v;
                          if (_formError != null &&
                              _formError!.contains('شروط')) {
                            _formError = null;
                          }
                        });
                      },
                      label: Text(
                        'أوافق على شروط الانتفاع وأدب طلب العلم',
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
                          label: 'إنشاء الحساب',
                          fullWidth: true,
                          isLoading: state is AuthLoading,
                          onPressed: _submit,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _LoginFooter(onTap: () => context.pop()),
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

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب؟ ',
          style: AppTextStyles.small.copyWith(color: AppColors.inkMuted),
        ),
        InkWell(
          onTap: onTap,
          child: Text(
            'سجّل الدخول',
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
