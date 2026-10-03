// lib/features/admin/loading_quotes/view/admin_loading_quote_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/loading_quote_entity.dart';
import '../cubit/admin_loading_quotes_cubit.dart';
import '../cubit/admin_loading_quotes_state.dart';

const int kQuoteTextMax = 200;
const int kQuoteSourceMax = 60;

class AdminLoadingQuoteFormPage extends StatefulWidget {
  final LoadingQuoteEntity? existing;

  /// sort_order to assign when creating a new quote (append at the end).
  final int nextSortOrder;

  const AdminLoadingQuoteFormPage({
    super.key,
    this.existing,
    required this.nextSortOrder,
  });

  bool get isEdit => existing != null;

  @override
  State<AdminLoadingQuoteFormPage> createState() =>
      _AdminLoadingQuoteFormPageState();
}

class _AdminLoadingQuoteFormPageState extends State<AdminLoadingQuoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textCtrl;
  late final TextEditingController _sourceCtrl;
  late bool _isActive;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _textCtrl = TextEditingController(text: q?.text ?? '');
    _sourceCtrl = TextEditingController(text: q?.source ?? '');
    _isActive = q?.isActive ?? true;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final cubit = context.read<AdminLoadingQuotesCubit>();
    final text = _textCtrl.text.trim();
    final source = _sourceCtrl.text.trim();
    if (widget.isEdit) {
      cubit.updateQuote(
        id: widget.existing!.id,
        text: text,
        source: source,
        isActive: _isActive,
      );
    } else {
      cubit.createQuote(
        text: text,
        source: source,
        sortOrder: widget.nextSortOrder,
        isActive: _isActive,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminLoadingQuotesCubit, AdminLoadingQuotesState>(
      listener: (context, state) {
        if (state is AdminLoadingQuotesSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحفظ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          if (mounted) Navigator.of(context).pop();
        } else if (state is AdminLoadingQuotesFormError) {
          setState(() => _submitting = false);
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
        appBar: AppBar(title: Text(widget.isEdit ? 'تعديل النص' : 'نص جديد')),
        body: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _textCtrl,
                  maxLength: kQuoteTextMax,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'النص *',
                    hintText: 'النص الذي يظهر على شاشة التحميل',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'النص مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _sourceCtrl,
                  maxLength: kQuoteSourceMax,
                  decoration: const InputDecoration(
                    labelText: 'المصدر (اختياري)',
                    hintText: 'مثال: متفق عليه · الأنفال: 60',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('مفعّل (يظهر للطلاب)'),
                  contentPadding: EdgeInsetsDirectional.zero,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: widget.isEdit ? 'حفظ التعديلات' : 'إضافة',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
