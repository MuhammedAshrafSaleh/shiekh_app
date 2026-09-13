// lib/features/admin/banners/view/admin_banner_form_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/banner_entity.dart';
import '../../../../models/book_entity.dart';
import '../cubit/admin_banner_cubit.dart';
import '../cubit/admin_banner_state.dart';

class AdminBannerFormPage extends StatefulWidget {
  final BannerEntity? existing;
  final List<BookEntity> books;

  const AdminBannerFormPage({super.key, this.existing, required this.books});

  bool get isEdit => existing != null;

  @override
  State<AdminBannerFormPage> createState() => _AdminBannerFormPageState();
}

class _AdminBannerFormPageState extends State<AdminBannerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _externalLinkCtrl;

  bool _isActive = true;
  String? _linkedBookId; // null = no book link (CC-26)
  String? _imageUrl;
  bool _uploadingImage = false;

  // Link type: 'none' | 'book' | 'external'
  String _linkType = 'none';

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _orderCtrl = TextEditingController(text: b?.orderIndex.toString() ?? '0');
    _externalLinkCtrl = TextEditingController(text: b?.externalLink ?? '');
    _isActive = b?.isActive ?? true;
    _imageUrl = b?.imageUrl;
    if (b?.linkedBookId != null) {
      _linkType = 'book';
      _linkedBookId = b!.linkedBookId;
    } else if (b?.externalLink != null) {
      _linkType = 'external';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    _externalLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBannerCubit, AdminBannerState>(
      listener: (context, state) {
        if (state is AdminBannerMutationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEdit ? 'تم تحديث البانر' : 'تم إضافة البانر',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          if (mounted) Navigator.of(context).pop();
        } else if (state is AdminBannerError) {
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
        appBar: AppBar(
          title: Text(widget.isEdit ? 'تعديل البانر' : 'بانر جديد'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image picker
                _ImagePickerWidget(
                  imageUrl: _imageUrl,
                  uploading: _uploadingImage,
                  onPick: _pickImage,
                ),
                const SizedBox(height: AppSpacing.md),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان البانر *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (اختياري)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),

                // Order
                TextFormField(
                  controller: _orderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ترتيب الظهور *',
                    hintText: '0 = الأول',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الترتيب مطلوب';
                    if (int.tryParse(v.trim()) == null)
                      return 'أدخل رقماً صحيحاً';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Active toggle
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('نشط (يظهر في الرئيسية)'),
                  contentPadding: EdgeInsetsDirectional.zero,
                ),
                const SizedBox(height: AppSpacing.md),

                // Link type — CC-26: nullable target allowed
                Text(
                  'الرابط عند النقر',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'none', label: Text('بدون رابط')),
                    ButtonSegment(value: 'book', label: Text('كتاب')),
                    ButtonSegment(value: 'external', label: Text('رابط خارجي')),
                  ],
                  selected: {_linkType},
                  onSelectionChanged: (s) =>
                      setState(() => _linkType = s.first),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_linkType == 'book') ...[
                  if (widget.books.isEmpty)
                    const Text('لا توجد كتب منشورة')
                  else
                    DropdownButtonFormField<String?>(
                      key: ValueKey(_linkedBookId),
                      initialValue: _linkedBookId,
                      decoration: const InputDecoration(
                        labelText: 'اختر كتاباً',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— اختر كتاباً —'),
                        ),
                        ...widget.books.map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.title),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _linkedBookId = v),
                      validator: (v) => _linkType == 'book' && v == null
                          ? 'اختر كتاباً'
                          : null,
                    ),
                ] else if (_linkType == 'external') ...[
                  TextFormField(
                    controller: _externalLinkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الرابط الخارجي',
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) =>
                        _linkType == 'external' &&
                            (v == null || v.trim().isEmpty)
                        ? 'الرابط مطلوب'
                        : null,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                PrimaryButton(
                  label: widget.isEdit ? 'حفظ التعديلات' : 'إضافة البانر',
                  isLoading: _uploadingImage,
                  onPressed: _uploadingImage ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingImage = true);
    final url = await context.read<AdminBannerCubit>().uploadImageAndGetUrl(
      picked.path,
    );
    if (!mounted) return;
    setState(() {
      _uploadingImage = false;
      if (url != null) _imageUrl = url;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final order = int.parse(_orderCtrl.text.trim());

    final linkedBookId = _linkType == 'book' ? _linkedBookId : null;
    final externalLink = _linkType == 'external'
        ? _externalLinkCtrl.text.trim()
        : null;

    if (widget.isEdit) {
      context.read<AdminBannerCubit>().updateBanner(
        id: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        imageUrl: _imageUrl,
        linkedBookId: linkedBookId,
        externalLink: externalLink,
        orderIndex: order,
        isActive: _isActive,
      );
    } else {
      context.read<AdminBannerCubit>().createBanner(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        imageUrl: _imageUrl,
        linkedBookId: linkedBookId,
        externalLink: externalLink,
        orderIndex: order,
        isActive: _isActive,
      );
    }
  }
}

class _ImagePickerWidget extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;

  const _ImagePickerWidget({
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
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
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
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'إضافة صورة البانر',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}
