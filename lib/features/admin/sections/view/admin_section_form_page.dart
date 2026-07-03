// lib/features/admin/sections/view/admin_section_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/icon_registry.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/section_entity.dart';
import '../cubit/admin_sections_cubit.dart';
import '../cubit/admin_sections_state.dart';

class AdminSectionFormPage extends StatefulWidget {
  final SectionEntity? existing;
  const AdminSectionFormPage({super.key, this.existing});

  @override
  State<AdminSectionFormPage> createState() => _AdminSectionFormPageState();
}

class _AdminSectionFormPageState extends State<AdminSectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedIcon;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _selectedIcon = widget.existing?.icon ?? SectionIcons.keys.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminSectionsCubit, AdminSectionsState>(
      listener: (context, state) {
        if (state is AdminSectionMutationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'تم تحديث القسم' : 'تم إضافة القسم'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
          if (mounted) Navigator.of(context).pop();
        } else if (state is AdminSectionsError) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل القسم' : 'قسم جديد'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم القسم *',
                    hintText: 'مثال: علوم الحديث',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (اختياري)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'الأيقونة',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _IconPicker(
                  selected: _selectedIcon,
                  onChanged: (key) => setState(() => _selectedIcon = key),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isEdit ? 'حفظ التعديلات' : 'إضافة القسم',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    if (_isEdit) {
      context.read<AdminSectionsCubit>().updateSection(
            id: widget.existing!.id,
            name: _nameCtrl.text.trim(),
            icon: _selectedIcon,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );
    } else {
      context.read<AdminSectionsCubit>().createSection(
            name: _nameCtrl.text.trim(),
            icon: _selectedIcon,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );
    }
  }
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _IconPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: SectionIcons.keys.map((key) {
        final isSelected = key == selected;
        return GestureDetector(
          onTap: () => onChanged(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  SectionIcons.fromKey(key),
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  SectionIcons.labels[key] ?? key,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                            : null,
                      ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
