// lib/features/auth/view/reset_sent_page.dart
//
// Heritage redesign (Auth Phase 1, no numbered mockup). SheikhyAuthHeader band
// + OrnamentDivider + gold-ring mail motif (CustomPainter) + email address +
// primary "open mail app" CTA + resend row with 60-second countdown.
//
// Visual-only migration: AuthCubit contract unchanged. resetPassword(email) is
// called on resend — same as before. No Bloc/Cubit/Repository touched.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/ornament_divider.dart';
import '../../../core/widgets/sheikhy_auth_header.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class ResetSentPage extends StatefulWidget {
  final String email;

  const ResetSentPage({super.key, required this.email});

  @override
  State<ResetSentPage> createState() => _ResetSentPageState();
}

class _ResetSentPageState extends State<ResetSentPage> {
  static const int _cooldown = 60;
  int _remaining = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _remaining = _cooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          t.cancel();
        }
      });
    });
  }

  Future<void> _openMailApp() async {
    final uri = Uri(scheme: 'mailto');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح تطبيق البريد الإلكتروني')),
      );
    }
  }

  void _resend() {
    context.read<AuthCubit>().resetPassword(widget.email);
    _startCountdown();
  }

  String _resendLabel() {
    if (_remaining <= 0) return 'إعادة الإرسال';
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return 'إعادة الإرسال ($m:$s)';
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _remaining <= 0;

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (_, curr) => curr is AuthError,
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            SheikhyAuthHeader(
              title: 'تم إرسال الرابط',
              subtitle: 'تحقق من بريدك الإلكتروني',
              onBack: () => context.pop(),
              backLabel: 'رجوع',
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
                    const OrnamentDivider(),
                    const SizedBox(height: AppSpacing.s6),
                    const Center(child: _MailMotif()),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'تم إرسال الرابط بنجاح',
                      style: AppTextStyles.h2.copyWith(color: AppColors.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      'أرسلنا رابط تعيين كلمة المرور إلى',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      widget.email,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      'افتح بريدك الإلكتروني واضغط على الرابط',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkFaint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SheikhyButton.primary(
                      label: 'افتح تطبيق البريد الإلكتروني',
                      fullWidth: true,
                      onPressed: _openMailApp,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'لم يصلك البريد؟ ',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        SheikhyButton.text(
                          label: _resendLabel(),
                          onPressed: canResend ? _resend : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Center(
                      child: SheikhyButton.text(
                        label: 'العودة لتسجيل الدخول',
                        onPressed: () => context.go('/login'),
                      ),
                    ),
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

/// Gold double-ring with diamond cardinal marks and a mail icon at centre.
/// Drawn entirely with CustomPainter — no raster assets.
class _MailMotif extends StatelessWidget {
  const _MailMotif();

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _GoldRingPainter(),
          ),
          const Icon(Icons.mail_outline, size: 34, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _GoldRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2 - 2;
    final innerR = outerR - 6;

    final ringStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.gold
      ..strokeWidth = 1.5;

    final bgFill = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.gold.withValues(alpha: 0.07);

    // Faint fill between the two rings
    canvas.drawCircle(Offset(cx, cy), outerR, bgFill);
    // Outer ring
    canvas.drawCircle(Offset(cx, cy), outerR, ringStroke);
    // Inner ring
    canvas.drawCircle(Offset(cx, cy), innerR, ringStroke);

    // Small filled diamonds at the four cardinal points on the outer ring
    final diamondFill = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.gold;
    const d = 3.5;

    for (final pt in [
      Offset(cx, cy - outerR),
      Offset(cx, cy + outerR),
      Offset(cx - outerR, cy),
      Offset(cx + outerR, cy),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(pt.dx, pt.dy - d)
          ..lineTo(pt.dx + d, pt.dy)
          ..lineTo(pt.dx, pt.dy + d)
          ..lineTo(pt.dx - d, pt.dy)
          ..close(),
        diamondFill,
      );
    }
  }

  @override
  bool shouldRepaint(_GoldRingPainter old) => false;
}
