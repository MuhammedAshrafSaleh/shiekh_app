// lib/features/admin/ai_settings/view/admin_ai_key_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../cubit/admin_ai_key_cubit.dart';
import '../cubit/admin_ai_key_state.dart';
import '../data/admin_ai_settings_repository.dart';

class AdminAiKeyPage extends StatefulWidget {
  const AdminAiKeyPage({super.key});

  @override
  State<AdminAiKeyPage> createState() => _AdminAiKeyPageState();
}

class _AdminAiKeyPageState extends State<AdminAiKeyPage> {
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AdminAiKeyCubit>().load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<AdminAiKeyCubit>().saveKey(key);
    _keyCtrl.clear();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المفتاح'),
        content: const Text(
          'سيتوقف توليد الأسئلة بالذكاء الاصطناعي حتى تضيف مفتاحًا جديدًا. '
          'هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AdminAiKeyCubit>().clearKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('مفتاح الذكاء الاصطناعي')),
      body: BlocConsumer<AdminAiKeyCubit, AdminAiKeyState>(
        listenWhen: (prev, curr) =>
            curr is AdminAiKeyLoaded &&
            (prev is! AdminAiKeyLoaded ||
                prev.successNonce != curr.successNonce ||
                prev.errorNonce != curr.errorNonce),
        listener: (context, state) {
          if (state is! AdminAiKeyLoaded) return;
          final messenger = ScaffoldMessenger.of(context);
          if (state.transientSuccess != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientSuccess!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state.transientError != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.transientError!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminAiKeyLoading || state is AdminAiKeyInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminAiKeyError) {
            return ErrorState(
              message: state.message,
              onRetry: () => context.read<AdminAiKeyCubit>().load(),
            );
          }
          final loaded = state as AdminAiKeyLoaded;
          return _Body(
            status: loaded.status,
            isSaving: loaded.isSaving,
            keyCtrl: _keyCtrl,
            onSave: _save,
            onClear: _confirmClear,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final GeminiKeyStatus status;
  final bool isSaving;
  final TextEditingController keyCtrl;
  final VoidCallback onSave;
  final VoidCallback onClear;

  const _Body({
    required this.status,
    required this.isSaving,
    required this.keyCtrl,
    required this.onSave,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    status.isSet ? Icons.check_circle : Icons.cancel_outlined,
                    color: status.isSet ? Colors.green : theme.disabledColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      status.isSet
                          ? 'الحالة: مُفعّل  (••••••••${status.last4 ?? ''})'
                          : 'الحالة: غير مُفعّل',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'مفتاح الذكاء الاصطناعي (Gemini) المستخدم لتوليد الأسئلة وتفريغ '
            'المحاضرات. الصق مفتاحًا جديدًا لتحديثه.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: keyCtrl,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'لصق مفتاح جديد',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'حفظ',
            isLoading: isSaving,
            onPressed: isSaving ? null : onSave,
          ),
          if (status.isSet) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: isSaving ? null : onClear,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'حذف المفتاح',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        ],
      ),
    );
  }
}
