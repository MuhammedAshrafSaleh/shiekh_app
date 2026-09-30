// test/widget_test.dart
//
// Retroactive widget coverage for Phase 1 auth screens.
// Verifies each page renders its required Arabic copy and runs client-side
// validation. AuthRepository is mocked so no Supabase project is needed.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sheikhy_app/core/audio/sound_service.dart';
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
    // SoundService is read by tappable widgets (SheikhyButton) and the splash;
    // provide an uninitialised instance (play() no-ops safely without init).
    home: RepositoryProvider<SoundService>(
      create: (_) => SoundService(),
      child: BlocProvider<AuthCubit>(create: (_) => _stubCubit(), child: child),
    ),
  );
}

void main() {
  testWidgets('SplashPage builds', (tester) async {
    await tester.pumpWidget(_wrap(const SplashPage()));
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
  });

  testWidgets('LoginPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const LoginPage()));
    await tester.pump();
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(find.text('أكمل ما بدأته في مجالس العلم'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
    expect(find.text('نسيتها؟'), findsOneWidget);
    expect(find.text('أنشئ حسابًا'), findsOneWidget);
  });

  testWidgets('LoginPage validates empty fields', (tester) async {
    await tester.pumpWidget(_wrap(const LoginPage()));
    await tester.pump();
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل بريدك الإلكتروني'), findsOneWidget);
  });

  testWidgets('SignupPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const SignupPage()));
    await tester.pump();
    expect(find.text('انضمّ إلى المجلس'), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
    expect(find.text('الاسم الكامل'), findsOneWidget);
  });

  testWidgets('SignupPage validates empty fields', (tester) async {
    await tester.pumpWidget(_wrap(const SignupPage()));
    await tester.pump();
    final submit = find.text('إنشاء الحساب');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('أدخل اسمك الكامل'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const ForgotPasswordPage()));
    await tester.pump();
    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    expect(find.text('أرسل رمز التحقق'), findsOneWidget);
    expect(find.text('تذكرتها؟ '), findsOneWidget);
  });

  testWidgets('ResetSentPage shows email and resend UI', (tester) async {
    await tester.pumpWidget(
      _wrap(const ResetSentPage(email: 'test@example.com')),
    );
    await tester.pump();
    expect(find.text('تم إرسال الرابط بنجاح'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('افتح تطبيق البريد الإلكتروني'), findsOneWidget);
  });
}
