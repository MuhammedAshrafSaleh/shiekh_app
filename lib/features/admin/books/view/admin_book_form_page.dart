// lib/features/admin/books/view/admin_book_form_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/section_entity.dart';
import '../cubit/admin_book_cubit.dart';
import '../cubit/admin_book_state.dart';

class AdminBookFormPage extends StatefulWidget {
  final String? bookId;
  const AdminBookFormPage({super.key, this.bookId});

  bool get isEdit => bookId != null;

  @override
  State<AdminBookFormPage> createState() => _AdminBookFormPageState();
}

class _AdminBookFormPageState extends State<AdminBookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _featuredOrderCtrl = TextEditingController();

  String? _selectedSectionId;
  String _status = 'draft';
  String _reviewStatus = 'in_review';
  bool _isFeatured = false;
  String? _coverImageUrl;
  bool _uploadingCover = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _featuredOrderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: BlocConsumer<AdminBookCubit, AdminBookState>(
      listener: (context, state) {
        if (state is AdminBookFormReady && !_initialized) {
          _initialized = true;
          if (state.existing != null) {
            final b = state.existing!;
            _titleCtrl.text = b.title;
            _descCtrl.text = b.description ?? '';
            _selectedSectionId = b.sectionId;
            _status = b.status;
            _reviewStatus = b.reviewStatus;
            _isFeatured = b.isFeatured;
            _featuredOrderCtrl.text = b.featuredOrder?.toString() ?? '';
            _coverImageUrl = b.coverImageUrl;
          } else if (state.sections.isNotEmpty) {
            _selectedSectionId = state.sections.first.id;
          }
        }
        if (state is AdminBookSaveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.isEdit
                ? 'تم تحديث الكتاب بنجاح'
                : 'تم إضافة الكتاب بنجاح'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
          if (mounted) Navigator.of(context).pop(state.book);
        } else if (state is AdminBookError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
          // Re-load form to recover
          context.read<AdminBookCubit>().loadForm(bookId: widget.bookId);
        }
      },
      builder: (context, state) {
          if (state is AdminBookLoading) {
            return Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: Text(widget.isEdit ? 'تعديل الكتاب' : 'كتاب جديد'),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

        final sections = state is AdminBookFormReady
            ? state.sections
            : <SectionEntity>[];
        final featuredCount =
            state is AdminBookFormReady ? state.featuredCount : 0;
        final isSaving = state is AdminBookSaving;

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Text(widget.isEdit ? 'تعديل الكتاب' : 'كتاب جديد'),
          ),
          body: SingleChildScrollView(
            padding:
                const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image
                  _CoverPicker(
                    imageUrl: _coverImageUrl,
                    uploading: _uploadingCover,
                    onPick: () => _pickCover(context),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان الكتاب *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Section dropdown
                  if (sections.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedSectionId),
                      initialValue: _selectedSectionId,
                      decoration: const InputDecoration(labelText: 'القسم العلمي *'),
                      items: sections
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedSectionId = v),
                      validator: (v) =>
                          v == null ? 'اختر قسماً' : null,
                    ),
                  const SizedBox(height: AppSpacing.md),

                  // Status (publish_status)
                  Text(
                    'حالة النشر',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'draft', label: Text('مسودة')),
                      ButtonSegment(value: 'published', label: Text('منشور')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) =>
                        setState(() => _status = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Review status
                  Text(
                    'حالة المراجعة الداخلية',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'in_review', label: Text('قيد المراجعة')),
                      ButtonSegment(
                          value: 'completed', label: Text('مكتمل')),
                    ],
                    selected: {_reviewStatus},
                    onSelectionChanged: (s) =>
                        setState(() => _reviewStatus = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Featured toggle
                  SwitchListTile(
                    value: _isFeatured,
                    onChanged: (v) {
                      // CC-24: warn if already 5 featured books
                      if (v && featuredCount >= 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تنبيه: يُنصح بعدم تمييز أكثر من 5 كتب في الصفحة الرئيسية',
                            ),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                      setState(() => _isFeatured = v);
                    },
                    activeThumbColor: AppColors.gold,
                    title: const Text('كتاب مميز في الرئيسية'),
                    subtitle: const Text('يظهر في قسم "أهم الكتب"'),
                    contentPadding: EdgeInsetsDirectional.zero,
                  ),

                  if (_isFeatured) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _featuredOrderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب الظهور (اختياري)',
                        hintText: '1 = الأول',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: widget.isEdit ? 'حفظ التعديلات' : 'إضافة الكتاب',
                    isLoading: isSaving || _uploadingCover,
                    onPressed: isSaving || _uploadingCover ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  Future<void> _pickCover(BuildContext context) async {
    final cubit = context.read<AdminBookCubit>();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingCover = true);
    final url = await cubit.uploadCoverAndGetUrl(picked.path);
    if (!mounted) return;
    setState(() {
      _uploadingCover = false;
      if (url != null) _coverImageUrl = url;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSectionId == null) return;

    final order = int.tryParse(_featuredOrderCtrl.text.trim());
    context.read<AdminBookCubit>().save(
          bookId: widget.bookId,
          sectionId: _selectedSectionId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          coverImageUrl: _coverImageUrl,
          status: _status,
          reviewStatus: _reviewStatus,
          isFeatured: _isFeatured,
          featuredOrder: _isFeatured ? order : null,
        );
  }
}

class _CoverPicker extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;

  const _CoverPicker({
    this.imageUrl,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onPick,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator())
            : imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 180,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'إضافة صورة الغلاف',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
