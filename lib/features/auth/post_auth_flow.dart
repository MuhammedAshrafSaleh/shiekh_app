// lib/features/auth/post_auth_flow.dart
//
// Finishes a guest→registered journey (enroll in the gated book, then return to
// where the guest was blocked). This is driven from a DURABLE owner — the
// app-level auth listener (app.dart) — not the signup/login page, so it can't be
// lost if that page is disposed mid-conversion by a router rebuild.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../books/data/book_repository.dart';
import 'pending_conversion.dart';

/// Enrolls the now-registered user in [enrollBookId] (**awaited** — a user must
/// never land on gated content still unenrolled), then navigates to [returnTo]
/// (falling back to /home). On enroll failure the user is sent to the book page
/// (where, as a registered user, they can retry) rather than into the gated
/// content. The pending intent is cleared once handled either way.
Future<void> completeGuestReturn({
  required GoRouter router,
  required BookRepository bookRepo,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
  String? returnTo,
  String? enrollBookId,
}) async {
  if (enrollBookId != null && enrollBookId.isNotEmpty) {
    final result = await bookRepo.enrollInBook(enrollBookId);
    final Failure? failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('تعذّر إكمال التسجيل في الكتاب: ${failure.message}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
      await PendingConversion.clear();
      // Don't drop them into gated content unenrolled — land on the book page.
      router.go('/books/$enrollBookId');
      return;
    }
  }

  await PendingConversion.clear();
  router.go((returnTo != null && returnTo.isNotEmpty) ? returnTo : '/home');
}
