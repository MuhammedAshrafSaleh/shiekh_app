// lib/features/admin/notifications/view/admin_notification_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../cubit/admin_notifications_state.dart';

class AdminNotificationFormPage extends StatefulWidget {
  const AdminNotificationFormPage({super.key});

  @override
  State<AdminNotificationFormPage> createState() =>
      _AdminNotificationFormPageState();
}

class _AdminNotificationFormPageState extends State<AdminNotificationFormPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String _type = 'general';
  bool _isImmediate = true;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));

  static const int _titleMax = 60;
  static const int _bodyMax = 200;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العنوان والنص مطلوبان'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final sendAt = _isImmediate ? DateTime.now() : _scheduledAt;
    final ok = await context.read<AdminNotificationsCubit>().send(
      type: _type,
      title: title,
      body: body,
      linkUrl: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      sendAt: sendAt,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإشعار بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final typeOptions = [
      ('general', 'عام', Icons.notifications_outlined),
      ('live_stream', 'بث مباشر', Icons.live_tv_outlined),
      ('new_lesson', 'درس جديد', Icons.play_lesson_outlined),
      ('reminder', 'تذكير', Icons.alarm_outlined),
    ];

    return BlocConsumer<AdminNotificationsCubit, AdminNotificationsState>(
      listener: (context, state) {
        if (state is AdminNotificationsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSending = state is AdminNotificationsSending;

        return Scaffold(
          appBar: AppBar(title: const Text('إشعار جديد')),
          body: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector
                Text(
                  'نوع الإشعار',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: typeOptions.map((opt) {
                    final (value, label, icon) = opt;
                    return ChoiceChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      selected: _type == value,
                      onSelected: (_) => setState(() => _type = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title with char counter
                ListenableBuilder(
                  listenable: _titleCtrl,
                  builder: (context, _) => TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'عنوان الإشعار *',
                      counterText: '${_titleCtrl.text.length}/$_titleMax',
                    ),
                    maxLength: _titleMax,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${_titleCtrl.text.length}/$_titleMax',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Body with char counter
                ListenableBuilder(
                  listenable: _bodyCtrl,
                  builder: (context, _) => TextField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نص الإشعار *',
                      hintText: 'النص الكامل للإشعار...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: _bodyMax,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${_bodyCtrl.text.length}/$_bodyMax',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Optional link
                TextField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رابط (اختياري)',
                    hintText: 'https://... أو رابط داخلي',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Timing
                Text(
                  'توقيت الإرسال',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('الآن')),
                    ButtonSegment(value: false, label: Text('مجدول')),
                  ],
                  selected: {_isImmediate},
                  onSelectionChanged: (s) =>
                      setState(() => _isImmediate = s.first),
                ),
                if (!_isImmediate) ...[
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsetsDirectional.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(
                      '${_scheduledAt.year}/${_scheduledAt.month}/${_scheduledAt.day} '
                      '${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
                    ),
                    subtitle: const Text('اضغط لتغيير الوقت'),
                    onTap: _pickDateTime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Preview
                _NotificationPreview(
                  type: _type,
                  titleCtrl: _titleCtrl,
                  bodyCtrl: _bodyCtrl,
                ),
                const SizedBox(height: AppSpacing.lg),

                FilledButton.icon(
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isImmediate ? 'إرسال الآن' : 'جدولة الإشعار'),
                  onPressed: isSending ? null : _send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  final String type;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;

  const _NotificationPreview({
    required this.type,
    required this.titleCtrl,
    required this.bodyCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcons = {
      'general': Icons.notifications_outlined,
      'live_stream': Icons.live_tv_outlined,
      'new_lesson': Icons.play_lesson_outlined,
      'reminder': Icons.alarm_outlined,
      'achievement': Icons.emoji_events_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معاينة',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([titleCtrl, bodyCtrl]),
          builder: (context, _) => Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Icon(
                    typeIcons[type] ?? Icons.notifications_outlined,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleCtrl.text.isEmpty
                            ? 'عنوان الإشعار'
                            : titleCtrl.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bodyCtrl.text.isEmpty
                            ? 'نص الإشعار سيظهر هنا...'
                            : bodyCtrl.text,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
