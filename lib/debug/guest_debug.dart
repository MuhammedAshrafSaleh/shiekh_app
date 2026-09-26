// lib/debug/guest_debug.dart
//
// ⚠️ TEMPORARY — Stage 1 guest-mode verification harness. DELETE THIS FILE
// (and its two call sites in onboarding_page.dart / home_page.dart) before
// building Stage 2's real gating UI. Everything here is gated behind
// `kDebugMode`, so it is inert in release builds.
//
// Purpose: let a human verify Stage 1 end-to-end —
//   1. GuestDebugOnboardingButton → AuthCubit.continueAsGuest() (lands on /home)
//   2. GuestDebugFab (on /home)     → runGuestSelfTest() prints a PASS/FAIL
//      report to the debug console covering every guest DB-rejection check and
//      the read-only browse checks.
//
// It talks to Supabase directly on purpose — this is a throwaway probe, NOT
// production code, and must not be copied into a repository/cubit.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/cubit/auth_cubit.dart';

// A syntactically-valid UUID used only as a throwaway id for the "expect
// rejection" RPC calls (the guest guard fires before any id lookup).
const String _bogusUuid = '00000000-0000-0000-0000-000000000000';

/// Temporary onboarding entry point → starts a guest (anonymous) session.
class GuestDebugOnboardingButton extends StatelessWidget {
  const GuestDebugOnboardingButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          minimumSize: const Size.fromHeight(44),
        ),
        icon: const Icon(Icons.bug_report_outlined),
        label: const Text('DEBUG: متابعة كزائر (temporary)'),
        onPressed: () => context.read<AuthCubit>().continueAsGuest(),
      ),
    );
  }
}

/// Temporary /home overlay → runs the guest self-test. Only shows in debug and
/// only when the current session is anonymous.
class GuestDebugFab extends StatelessWidget {
  const GuestDebugFab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !user.isAnonymous) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      backgroundColor: Colors.deepPurple,
      icon: const Icon(Icons.science_outlined),
      label: const Text('DEBUG: guest self-test'),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('جارٍ تشغيل فحص الزائر… راجع الـ console')),
        );
        final report = await runGuestSelfTest();
        // debugPrint truncates long strings, so print line-by-line.
        for (final line in report.split('\n')) {
          debugPrint(line);
        }
        if (messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('انتهى فحص الزائر — راجع الـ console')),
          );
        }
      },
    );
  }
}

/// Runs every Stage-1 guest verification check against Supabase as the current
/// (expected anonymous) session and returns a formatted report.
Future<String> runGuestSelfTest() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final b = StringBuffer()
    ..writeln('══════════════════════════════════════════════')
    ..writeln(' GUEST MODE — Stage 1 self-test')
    ..writeln('══════════════════════════════════════════════');

  if (user == null) {
    b.writeln('✗ No session at all — sign in as guest first.');
    return b.toString();
  }
  b
    ..writeln('user.id           = ${user.id}')
    ..writeln('user.isAnonymous  = ${user.isAnonymous}   ${user.isAnonymous ? "✓" : "✗ EXPECTED true"}')
    ..writeln('');

  // Grab real published ids so the insert checks hit RLS, not a FK error.
  String bookId = _bogusUuid;
  String lessonId = _bogusUuid;
  try {
    final books = await client
        .from('books')
        .select('id')
        .eq('status', 'published')
        .limit(1);
    if (books.isNotEmpty) bookId = books.first['id'] as String;
  } catch (_) {}
  try {
    final lessons = await client.from('lessons').select('id').limit(1);
    if (lessons.isNotEmpty) lessonId = lessons.first['id'] as String;
  } catch (_) {}

  b.writeln('── A. DB-rejection checks (guest must be BLOCKED) ──');
  await _expectBlocked(b, 'rpc submit_lesson_quiz', () => client.rpc(
        'submit_lesson_quiz',
        params: {'p_lesson_id': lessonId, 'p_answers': <String, dynamic>{}},
      ), mustContain: 'GUESTS_NOT_ALLOWED');
  await _expectBlocked(b, 'rpc submit_final_exam', () => client.rpc(
        'submit_final_exam',
        params: {
          'p_book_id': bookId,
          'p_answers': <String, dynamic>{},
          'p_started_at': DateTime.now().toUtc().toIso8601String(),
        },
      ), mustContain: 'GUESTS_NOT_ALLOWED');
  await _expectBlocked(b, 'rpc grade_lesson_quiz', () => client.rpc(
        'grade_lesson_quiz',
        params: {'p_lesson_id': lessonId, 'p_answers': <String, dynamic>{}},
      ), mustContain: 'GUESTS_NOT_ALLOWED');
  await _expectBlocked(b, 'insert enrollments (RLS)', () => client
      .from('enrollments')
      .insert({'user_id': user.id, 'book_id': bookId}));
  await _expectBlocked(b, 'insert lesson_progress (RLS)', () => client
      .from('lesson_progress')
      .insert({'user_id': user.id, 'lesson_id': lessonId, 'completed': false}));

  b.writeln('');
  b.writeln('── B. Student views (guest must see 0 rows) ──');
  await _expectRowCount(b, 'lesson_quiz_questions_student', 0,
      () => client.from('lesson_quiz_questions_student').select('id').limit(5));
  await _expectRowCount(b, 'final_exam_questions_student', 0,
      () => client.from('final_exam_questions_student').select('id').limit(5));
  await _expectRowCount(b, 'student_questions_public', 0,
      () => client.from('student_questions_public').select('id').limit(5));

  b.writeln('');
  b.writeln('── C. Browse must still work (guest allowed) ──');
  await _expectReadable(
      b, 'sections', () => client.from('sections').select('id').limit(50));
  await _expectReadable(
      b,
      'books (published)',
      () => client
          .from('books')
          .select('id')
          .eq('status', 'published')
          .limit(50));
  await _expectReadable(
      b,
      'home_banners (active)',
      () => client
          .from('home_banners')
          .select('id')
          .eq('is_active', true)
          .limit(50));
  await _expectReadable(
      b,
      'onboarding_slides (active)',
      () => client
          .from('onboarding_slides')
          .select('id')
          .eq('is_active', true)
          .limit(50));

  b.writeln('');
  b.writeln('── D. is_guest() claim ──');
  try {
    final r = await client.rpc('is_guest');
    final ok = r == true;
    b.writeln('${ok ? "✓" : "✗"} rpc is_guest() = $r   (expected true)');
  } catch (e) {
    b.writeln('✗ rpc is_guest() threw: $e');
  }

  b.writeln('══════════════════════════════════════════════');
  return b.toString();
}

Future<void> _expectBlocked(
  StringBuffer b,
  String label,
  Future<dynamic> Function() run, {
  String? mustContain,
}) async {
  try {
    await run();
    b.writeln('✗ $label — SUCCEEDED but should have been blocked!');
  } on PostgrestException catch (e) {
    final msg = '${e.message} ${e.code ?? ''}'.trim();
    if (mustContain != null && !msg.contains(mustContain)) {
      b.writeln('~ $label — blocked, but msg lacked "$mustContain": $msg');
    } else {
      b.writeln('✓ $label — blocked ($msg)');
    }
  } catch (e) {
    b.writeln('✓ $label — blocked ($e)');
  }
}

Future<void> _expectRowCount(
  StringBuffer b,
  String label,
  int expected,
  Future<List<dynamic>> Function() run,
) async {
  try {
    final rows = await run();
    final ok = rows.length == expected;
    b.writeln('${ok ? "✓" : "✗"} $label — ${rows.length} rows (expected $expected)');
  } catch (e) {
    b.writeln('✗ $label — threw: $e');
  }
}

Future<void> _expectReadable(
  StringBuffer b,
  String label,
  Future<List<dynamic>> Function() run,
) async {
  try {
    final rows = await run();
    b.writeln('✓ $label — readable (${rows.length} rows)');
  } catch (e) {
    b.writeln('✗ $label — threw: $e');
  }
}
