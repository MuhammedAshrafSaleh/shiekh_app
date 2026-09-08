// lib/features/auth/post_auth_flow.dart
//
// Shared "finish the guest journey" step, reused by the two paths that turn a
// guest into a signed-in registered user with a pending destination:
//   1. in-place conversion  (signup_page, convertGuest succeeds), and
//   2. email-collision sign-in (login_page, the email already existed).
//
// Both, on reaching a registered session, must: auto-enroll in the book the
// guest was blocked on, then return to the exact lesson they were opening.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../books/data/book_repository.dart';

/// Enrolls the now-registered user in [enrollBookId] (if given), then navigates
/// to [returnTo] (falling back to /home). Enrollment failure is surfaced as a
/// SnackBar but does not block navigation — the user still lands where intended.
Future<void> completeGuestReturn(
  BuildContext context, {
  String? returnTo,
  String? enrollBookId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final bookRepo = context.read<BookRepository>();

  if (enrollBookId != null && enrollBookId.isNotEmpty) {
    final result = await bookRepo.enrollInBook(enrollBookId);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      ),
      (_) {},
    );
  }

  router.go((returnTo != null && returnTo.isNotEmpty) ? returnTo : '/home');
}
