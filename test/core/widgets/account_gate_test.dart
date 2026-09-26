// test/core/widgets/account_gate_test.dart
//
// Covers the shared AccountGate (Stage 3):
//   • resolveGate — the pure reason × guest branch matrix (no widgets).
//   • AccountGate widget — inline panel renders the right CTA per branch,
//     honours copy overrides.
//   • AccountGate.showSheet — dialog is barrier-dismissible and "لاحقاً" pops
//     it with no side effect.
//   • AccountGate.guard — registered runs onAllowed (true, no dialog);
//     guest shows the sheet (false).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:sheikhy_app/core/audio/sound_service.dart';
import 'package:sheikhy_app/core/widgets/account_gate.dart';
import 'package:sheikhy_app/features/auth/cubit/auth_cubit.dart';
import 'package:sheikhy_app/features/auth/cubit/auth_state.dart';

class _MockAuthCubit extends Mock implements AuthCubit {}

class _MockUser extends Mock implements User {}

/// An AuthAuthenticated state whose isGuest is [guest].
AuthAuthenticated _authState({required bool guest}) {
  final user = _MockUser();
  when(() => user.id).thenReturn('u1');
  when(() => user.isAnonymous).thenReturn(guest);
  return AuthAuthenticated(user: user, role: UserRole.student);
}

/// Wraps [child] with the providers AccountGate + SheikhyButton read, forcing
/// RTL so the Arabic layout matches the running app.
Widget _wrap(Widget child, {required bool guest}) {
  final cubit = _MockAuthCubit();
  final state = _authState(guest: guest); // build before stubbing (no nested when)
  when(() => cubit.state).thenReturn(state);
  when(() => cubit.stream).thenAnswer((_) => const Stream<AuthState>.empty());
  // SoundService is provided ABOVE MaterialApp so dialogs (rendered in the root
  // overlay) can still read it, mirroring the app's root-level provider.
  return RepositoryProvider<SoundService>.value(
    value: SoundService(), // uninitialised → play() is a safe no-op
    child: MaterialApp(
      locale: const Locale('ar'),
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('resolveGate (pure branch matrix)', () {
    test('account + guest → blocked, sign-up CTA', () {
      final s = resolveGate(reason: GateReason.account, isGuest: true);
      expect(s.isAllowed, isFalse);
      expect(s.isSignup, isTrue);
      expect(s.ctaLabel, 'أنشئ حساباً');
    });

    test('account + registered → allowed (no gate)', () {
      final s = resolveGate(reason: GateReason.account, isGuest: false);
      expect(s.isAllowed, isTrue);
    });

    test('enrollment + guest → blocked, sign-up CTA', () {
      final s = resolveGate(reason: GateReason.enrollment, isGuest: true);
      expect(s.isAllowed, isFalse);
      expect(s.isSignup, isTrue);
      expect(s.ctaLabel, 'أنشئ حساباً');
    });

    test('enrollment + registered → blocked, enrol CTA', () {
      final s = resolveGate(reason: GateReason.enrollment, isGuest: false);
      expect(s.isAllowed, isFalse);
      expect(s.isSignup, isFalse);
      expect(s.ctaLabel, 'التسجيل في الكتاب');
    });
  });

  group('AccountGate inline panel', () {
    testWidgets('enrollment + guest shows sign-up CTA', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AccountGate(
            reason: GateReason.enrollment,
            returnTo: '/lessons/l1?bookId=b1',
            bookId: 'b1',
          ),
          guest: true,
        ),
      );
      expect(find.text('أنشئ حساباً'), findsOneWidget);
      expect(find.text('أنشئ حساباً لمتابعة التعلّم'), findsOneWidget);
    });

    testWidgets('enrollment + registered shows enrol CTA', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AccountGate(
            reason: GateReason.enrollment,
            returnTo: '/lessons/l1?bookId=b1',
            bookId: 'b1',
          ),
          guest: false,
        ),
      );
      expect(find.text('التسجيل في الكتاب'), findsOneWidget);
    });

    testWidgets('guest sees title + guestMessage, not enrolledMessage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AccountGate(
            reason: GateReason.enrollment,
            returnTo: '/x',
            bookId: 'b1',
            title: 'الاختبار غير متاح الآن',
            guestMessage: 'سجّل حساباً أولاً عشان تقدر تحل الاختبار',
            enrolledMessage: 'سجّل في الكتاب أولاً عشان تقدر تحل الاختبار',
          ),
          guest: true,
        ),
      );
      expect(find.text('الاختبار غير متاح الآن'), findsOneWidget);
      expect(
        find.text('سجّل حساباً أولاً عشان تقدر تحل الاختبار'),
        findsOneWidget,
      );
      expect(
        find.text('سجّل في الكتاب أولاً عشان تقدر تحل الاختبار'),
        findsNothing,
      );
    });

    testWidgets('registered sees title + enrolledMessage, not guestMessage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AccountGate(
            reason: GateReason.enrollment,
            returnTo: '/x',
            bookId: 'b1',
            title: 'الاختبار غير متاح الآن',
            guestMessage: 'سجّل حساباً أولاً عشان تقدر تحل الاختبار',
            enrolledMessage: 'سجّل في الكتاب أولاً عشان تقدر تحل الاختبار',
          ),
          guest: false,
        ),
      );
      expect(find.text('الاختبار غير متاح الآن'), findsOneWidget);
      expect(
        find.text('سجّل في الكتاب أولاً عشان تقدر تحل الاختبار'),
        findsOneWidget,
      );
      expect(
        find.text('سجّل حساباً أولاً عشان تقدر تحل الاختبار'),
        findsNothing,
      );
    });
  });

  group('AccountGate.showSheet', () {
    testWidgets('"لاحقاً" pops the dialog with no side effect', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AccountGate.showSheet(
                context,
                reason: GateReason.account,
                returnTo: '/x',
              ),
              child: const Text('open'),
            ),
          ),
          guest: true,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('أنشئ حساباً'), findsOneWidget); // dialog is up

      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('أنشئ حساباً'), findsNothing); // dismissed
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('barrier tap dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AccountGate.showSheet(
                context,
                reason: GateReason.account,
                returnTo: '/x',
              ),
              child: const Text('open'),
            ),
          ),
          guest: true,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // outside the card
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('AccountGate.guard', () {
    testWidgets('registered → runs onAllowed, returns true, no dialog', (
      tester,
    ) async {
      var allowed = false;
      late bool result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => result = AccountGate.guard(
                context,
                returnTo: '/x',
                onAllowed: () => allowed = true,
              ),
              child: const Text('act'),
            ),
          ),
          guest: false,
        ),
      );

      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      expect(allowed, isTrue);
      expect(result, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('guest → shows sheet, returns false, onAllowed not run', (
      tester,
    ) async {
      var allowed = false;
      late bool result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => result = AccountGate.guard(
                context,
                returnTo: '/x',
                onAllowed: () => allowed = true,
              ),
              child: const Text('act'),
            ),
          ),
          guest: true,
        ),
      );

      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      expect(allowed, isFalse);
      expect(result, isFalse);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('predicate form (no onAllowed): registered true / guest false', (
      tester,
    ) async {
      // Registered: guard is a no-op that returns true → inline flow continues.
      late bool registeredResult;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  registeredResult = AccountGate.guard(context, returnTo: '/x'),
              child: const Text('act'),
            ),
          ),
          guest: false,
        ),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      expect(registeredResult, isTrue);
      expect(find.byType(Dialog), findsNothing);

      // Guest: guard shows the sheet and returns false → inline flow aborts.
      late bool guestResult;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  guestResult = AccountGate.guard(context, returnTo: '/x'),
              child: const Text('act'),
            ),
          ),
          guest: true,
        ),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      expect(guestResult, isFalse);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('guestMessage override reaches the shown sheet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AccountGate.guard(
                context,
                returnTo: '/x',
                guestMessage: 'أنشئ حساباً لتدوين ملاحظاتك على الدرس',
              ),
              child: const Text('act'),
            ),
          ),
          guest: true,
        ),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      expect(
        find.text('أنشئ حساباً لتدوين ملاحظاتك على الدرس'),
        findsOneWidget,
      );
    });
  });
}
