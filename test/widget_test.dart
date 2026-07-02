// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sheikh_app/features/auth/view/login_page.dart';
import 'package:sheikh_app/features/auth/view/signup_page.dart';
import 'package:sheikh_app/features/auth/view/forgot_password_page.dart';
import 'package:sheikh_app/features/auth/view/reset_sent_page.dart';
import 'package:sheikh_app/features/auth/view/splash_page.dart';
import 'package:sheikh_app/features/auth/cubit/auth_cubit.dart';
import 'package:sheikh_app/features/auth/cubit/auth_state.dart';
import 'package:sheikh_app/core/theme/app_theme.dart';
import 'package:sheikh_app/features/notifications/cubit/connectivity_cubit.dart';

// Minimal AuthCubit mock
class _FakeAuthCubit extends AuthCubit {
  _FakeAuthCubit() : super(_FakeAuthRepo());
}

class _FakeAuthRepo extends Fake implements dynamic {
  @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(Widget child, {AuthState initialState = const _Unauth()}) {
  return MaterialApp(
    locale: const Locale('ar'),
    theme: AppTheme.light(primaryColor: const Color(0xFF1B5E20)),
    home: BlocProvider<AuthCubit>(
      create: (_) => _FakeAuthCubit(),
      child: child,
    ),
  );
}

class _Unauth extends AuthUnauthenticated {
  const _Unauth();
}

void main() {
  testWidgets('SplashPage builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(primaryColor: const Color(0xFF1B5E20)),
        home: const SplashPage(),
      ),
    );
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
  });

  testWidgets('LoginPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const LoginPage()));
    await tester.pump();
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(find.text('سجل دخولك لمتابعة دروسك'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    expect(find.text('سجل الآن'), findsOneWidget);
  });

  testWidgets('LoginPage validates empty fields', (tester) async {
    await tester.pumpWidget(_wrap(const LoginPage()));
    await tester.pump();
    // Tap login button with empty fields
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل بريدك الإلكتروني'), findsOneWidget);
  });

  testWidgets('SignupPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const SignupPage()));
    await tester.pump();
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
    expect(find.text('الاسم الكامل'), findsOneWidget);
  });

  testWidgets('SignupPage validates empty fields', (tester) async {
    await tester.pumpWidget(_wrap(const SignupPage()));
    await tester.pump();
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل اسمك الكامل'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage has required Arabic text', (tester) async {
    await tester.pumpWidget(_wrap(const ForgotPasswordPage()));
    await tester.pump();
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    expect(find.text('إرسال رابط إعادة التعيين'), findsOneWidget);
    expect(find.text('تذكرت كلمة المرور؟ '), findsOneWidget);
  });

  testWidgets('ResetSentPage shows email and resend UI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(primaryColor: const Color(0xFF1B5E20)),
        home: BlocProvider<AuthCubit>(
          create: (_) => _FakeAuthCubit(),
          child: const ResetSentPage(email: 'test@example.com'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('تم إرسال الرابط بنجاح'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('افتح تطبيق البريد الإلكتروني'), findsOneWidget);
  });
}
