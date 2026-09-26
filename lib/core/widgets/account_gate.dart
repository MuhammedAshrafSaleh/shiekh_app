// lib/core/widgets/account_gate.dart
//
// Shared account/enrollment gate (Stage 3). Replaces the ad-hoc gates that were
// scattered across screens (book_details `_showGuestSignupGate`/`_gateUnenrolled`,
// lesson `_QuizGate`, and the video/audio note-taking interceptors).
//
// The caller-facing variant is the *reason* a surface is gated — not the auth
// state. Guest-vs-registered is derived internally from [AuthCubit]:
//   • GateReason.account    — needs any real account; blocks guests only.
//   • GateReason.enrollment — needs enrollment in [bookId]; the caller decides a
//                             user is blocked and picks this reason. Guests are
//                             sent to sign-up (auto-enroll on return); registered
//                             users are sent to the book to enrol.
//
// Three entry points, one visual (`_GatePanel`, built from the shipped tokens):
//   • AccountGate(...)            — inline panel replacing a content region.
//   • AccountGate.showSheet(...)  — the same panel inside the shipped centred
//                                   Dialog (barrier-dismissible + "لاحقاً").
//   • AccountGate.guard(...)      — imperative interceptor for the `account`
//                                   reason: runs onAllowed for a registered user,
//                                   otherwise shows the sheet. Returns whether
//                                   the action was allowed.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sheikhy_button.dart';

/// Why a surface is gated. Drives the copy, CTA and destination.
enum GateReason { account, enrollment }

/// Pure presentation descriptor derived from [GateReason] + guest-ness.
/// Extracted so the branch matrix is unit-testable without widgets/providers.
@immutable
@visibleForTesting
class GateSpec {
  const GateSpec({
    required this.isAllowed,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.isSignup,
  });

  /// True when the current auth state already satisfies the reason (only ever
  /// true for `account` + a registered user) — the caller may proceed ungated.
  final bool isAllowed;
  final String title;
  final String message;
  final String ctaLabel;
  final IconData ctaIcon;

  /// true → CTA routes a guest to sign-up (conversion). false → CTA routes a
  /// registered user to enrol in the book.
  final bool isSignup;
}

/// Resolves the copy/CTA for a gate. Pure — no BuildContext, no side effects.
@visibleForTesting
GateSpec resolveGate({required GateReason reason, required bool isGuest}) {
  if (reason == GateReason.account) {
    if (!isGuest) {
      // Registered users already satisfy an account gate.
      return const GateSpec(
        isAllowed: true,
        title: '',
        message: '',
        ctaLabel: '',
        ctaIcon: Icons.check,
        isSignup: false,
      );
    }
    return const GateSpec(
      isAllowed: false,
      title: 'أنشئ حساباً للمتابعة',
      message:
          'تحتاج إلى حساب لاستخدام هذه الميزة. أنشئ حساباً مجانياً وسنعيدك إلى حيث توقفت.',
      ctaLabel: 'أنشئ حساباً',
      ctaIcon: Icons.person_add_alt_1_outlined,
      isSignup: true,
    );
  }

  // GateReason.enrollment — the caller only shows this when access is blocked.
  if (isGuest) {
    return const GateSpec(
      isAllowed: false,
      title: 'أنشئ حساباً لمتابعة التعلّم',
      message:
          'الدرس الأول متاح للجميع. لمتابعة بقية المحتوى أنشئ حساباً مجانياً وسنعيدك إلى حيث توقفت.',
      ctaLabel: 'أنشئ حساباً',
      ctaIcon: Icons.person_add_alt_1_outlined,
      isSignup: true,
    );
  }
  return const GateSpec(
    isAllowed: false,
    title: 'التسجيل في الكتاب مطلوب',
    message: 'سجّل في هذا الكتاب أولاً للوصول إلى هذا المحتوى.',
    ctaLabel: 'التسجيل في الكتاب',
    ctaIcon: Icons.how_to_reg_outlined,
    isSignup: false,
  );
}

bool _isGuest(BuildContext context) {
  final s = context.read<AuthCubit>().state;
  return s is AuthAuthenticated && s.isGuest;
}

/// Builds `/signup?returnTo=…&autoEnrollBookId=…`. Centralised so the four
/// former call sites no longer each hand-roll this URI.
String _signupLocation({required String returnTo, String? bookId}) {
  return Uri(
    path: '/signup',
    queryParameters: {'returnTo': returnTo, 'autoEnrollBookId': ?bookId},
  ).toString();
}

/// Runs the CTA action for a resolved [spec]: sign-up (guest) or enrol
/// (registered). Shared by the inline widget and the modal.
void _runCta(
  BuildContext context, {
  required GateSpec spec,
  required String returnTo,
  String? bookId,
  VoidCallback? onRegisteredAction,
}) {
  if (spec.isSignup) {
    context.push(_signupLocation(returnTo: returnTo, bookId: bookId));
  } else if (onRegisteredAction != null) {
    onRegisteredAction();
  } else if (bookId != null) {
    context.go('/books/$bookId');
  }
}

class AccountGate extends StatelessWidget {
  const AccountGate({
    super.key,
    required this.reason,
    required this.returnTo,
    this.bookId,
    this.title,
    this.guestMessage,
    this.enrolledMessage,
    this.onRegisteredAction,
  }) : assert(
         reason != GateReason.enrollment || bookId != null,
         'An enrollment gate requires a bookId (for auto-enroll on return).',
       );

  /// Why the surface is gated.
  final GateReason reason;

  /// Deep link to return to after a guest converts (carried into sign-up).
  final String returnTo;

  /// Book to auto-enroll into / navigate to. Required for [GateReason.enrollment].
  final String? bookId;

  /// Optional copy overrides so a surface can supply its own wording. [title]
  /// applies to both branches; the message override is per-branch so a surface
  /// can name exactly what is blocked (e.g. the quiz) instead of generic copy.
  /// [guestMessage] shows to a guest; [enrolledMessage] to a registered
  /// (not-enrolled) user. A null override falls back to the resolved default.
  final String? title;
  final String? guestMessage;
  final String? enrolledMessage;

  /// Overrides the registered-but-blocked CTA action (default: go to the book).
  final VoidCallback? onRegisteredAction;

  /// Modal form: the same panel inside the shipped centred Dialog.
  /// Barrier-dismissible; the "لاحقاً" secondary just pops (no side effect).
  static Future<void> showSheet(
    BuildContext context, {
    required GateReason reason,
    required String returnTo,
    String? bookId,
    String? title,
    String? guestMessage,
    String? enrolledMessage,
    VoidCallback? onRegisteredAction,
  }) {
    assert(
      reason != GateReason.enrollment || bookId != null,
      'An enrollment gate requires a bookId (for auto-enroll on return).',
    );
    final spec = resolveGate(reason: reason, isGuest: _isGuest(context));
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageGutter,
          vertical: AppSpacing.s8,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.s5),
          child: _GatePanel(
            title: title ?? spec.title,
            message: spec.isSignup
                ? (guestMessage ?? spec.message)
                : (enrolledMessage ?? spec.message),
            ctaLabel: spec.ctaLabel,
            ctaIcon: spec.ctaIcon,
            isSignup: spec.isSignup,
            onCta: () {
              Navigator.of(dialogCtx).pop();
              _runCta(
                context,
                spec: spec,
                returnTo: returnTo,
                bookId: bookId,
                onRegisteredAction: onRegisteredAction,
              );
            },
            onLater: () => Navigator.of(dialogCtx).pop(),
          ),
        ),
      ),
    );
  }

  /// Imperative interceptor for the `account` reason (note-taking, ask, etc.).
  /// Returns true when the action is allowed (registered user) — optionally
  /// running [onAllowed] — or shows the sheet and returns false for a guest.
  /// Use the bool return to guard an inline continuation:
  /// `if (!AccountGate.guard(context, returnTo: …)) return;`.
  /// [bookId], when given, is carried into sign-up so a converting guest is
  /// auto-enrolled in that book on return. [guestMessage] overrides the sheet's
  /// body so the prompt can name the surface (e.g. "…لتدوين ملاحظاتك"). Enrollment
  /// gates are not derivable from auth alone, so use [AccountGate] / [showSheet].
  static bool guard(
    BuildContext context, {
    required String returnTo,
    String? bookId,
    String? guestMessage,
    VoidCallback? onAllowed,
  }) {
    if (!_isGuest(context)) {
      onAllowed?.call();
      return true;
    }
    showSheet(
      context,
      reason: GateReason.account,
      returnTo: returnTo,
      bookId: bookId,
      guestMessage: guestMessage,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final spec = resolveGate(reason: reason, isGuest: _isGuest(context));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.pageGutter),
        child: _GatePanel(
          title: title ?? spec.title,
          message: spec.isSignup
              ? (guestMessage ?? spec.message)
              : (enrolledMessage ?? spec.message),
          ctaLabel: spec.ctaLabel,
          ctaIcon: spec.ctaIcon,
          isSignup: spec.isSignup,
          onCta: () => _runCta(
            context,
            spec: spec,
            returnTo: returnTo,
            bookId: bookId,
            onRegisteredAction: onRegisteredAction,
          ),
        ),
      ),
    );
  }
}

/// Shared visual: header icon in a tinted circle, h3 title, body message, a
/// primary CTA, and (in the modal) a "لاحقاً" secondary. Sign-up gates use the
/// primary tint + person icon; enrollment gates use the gold tint + lock icon,
/// matching the shipped `_showGuestSignupGate` / `_QuizGate` styling.
class _GatePanel extends StatelessWidget {
  const _GatePanel({
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.isSignup,
    required this.onCta,
    this.onLater,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final IconData ctaIcon;
  final bool isSignup;
  final VoidCallback onCta;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final headerBg = isSignup ? AppColors.primaryTint : AppColors.goldSoft;
    final headerFg = isSignup ? AppColors.primary : AppColors.goldDeep;
    final headerIcon = isSignup
        ? Icons.person_add_alt_1_outlined
        : Icons.lock_outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: headerBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(headerIcon, color: headerFg, size: 28),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s5),
        SheikhyButton.primary(
          fullWidth: true,
          label: ctaLabel,
          icon: Icon(ctaIcon),
          onPressed: onCta,
        ),
        if (onLater != null) ...[
          const SizedBox(height: AppSpacing.s2),
          SheikhyButton.secondary(
            fullWidth: true,
            label: 'لاحقاً',
            onPressed: onLater,
          ),
        ],
      ],
    );
  }
}
