// lib/features/admin/levels/view/admin_level_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/level_entity.dart';
import '../cubit/admin_levels_cubit.dart';
import '../cubit/admin_levels_state.dart';

/// Create / edit a level. Single `name` field — levels have no icon or
/// description (mirrors admin_section_form_page.dart, minus those fields).
/// A duplicate name surfaces as the Arabic SnackBar "اسم المستوى موجود بالفعل"
/// (the repository maps the uq_levels_name 23505 violation to a ValidationFailure).
class AdminLevelFormPage extends StatefulWidget {
  final LevelEntity? existing;
  const AdminLevelFormPage({super.key, this.existing});

  @override
  State<AdminLevelFormPage> createState() => _AdminLevelFormPageState();
}

class _AdminLevelFormPageState extends State<AdminLevelFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminLevelsCubit, AdminLevelsState>(
      listener: (context, state) {
        if (state is AdminLevelMutationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEdit ? 'تم تحديث المستوى' : 'تم إضافة المستوى'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          if (mounted) Navigator.of(context).pop();
        } else if (state is AdminLevelsError) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(_isEdit ? 'تعديل المستوى' : 'مستوى جديد')),
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
                    labelText: 'اسم المستوى *',
                    hintText: 'مثال: السنة التمهيدية',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isEdit ? 'حفظ التعديلات' : 'إضافة المستوى',
                  isLoading: _saving,
                  onPressed: _save,
                ),
                SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
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
    final cubit = context.read<AdminLevelsCubit>();
    if (_isEdit) {
      cubit.updateLevel(id: widget.existing!.id, name: _nameCtrl.text.trim());
    } else {
      cubit.createLevel(name: _nameCtrl.text.trim());
    }
  }
}
