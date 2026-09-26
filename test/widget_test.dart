// test/widget_test.dart
//
// Retroactive widget coverage for Phase 1 auth screens.
// Verifies each page renders its required Arabic copy and runs client-side
// validation. AuthRepository is mocked so no Supabase project is needed.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sheikhy_app/core/theme/app_theme.dart';
import 'package:sheikhy_app/features/auth/cubit/auth_cubit.dart';
import 'package:sheikhy_app/features/auth/data/auth_repository.dart';
import 'package:sheikhy_app/features/auth/view/forgot_password_page.dart';
import 'package:sheikhy_app/features/auth/view/login_page.dart';
import 'package:sheikhy_app/features/auth/view/reset_sent_page.dart';
import 'package:sheikhy_app/features/auth/view/signup_page.dart';
import 'package:sheikhy_app/features/auth/view/splash_page.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Builds an AuthCubit backed by a mock repo whose auth stream never fires,
/// so the page under test stays in its initial (unauthenticated) render.
AuthCubit _stubCubit() {
  final repo = _MockAuthRepository();
  when(() => repo.authStateChanges).thenAnswer((_) => const Stream.empty());
  when(() => repo.currentSession).thenReturn(null);
  return AuthCubit(repo);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    theme: AppTheme.light(primaryColor: const Color(0xFF1B5E20)),
    home: BlocProvider<AuthCubit>(create: (_) => _stubCubit(), child: child),
  );
}

void main() {
  testWidgets('SplashPage builds', (tester) async {
    await tester.pumpWidget(_wrap(const SplashPage()));
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
  });
