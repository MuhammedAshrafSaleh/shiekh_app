// lib/features/admin/suggestions/view/admin_suggestion_form_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show VideoId;

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/suggestion_entity.dart';
import '../cubit/admin_suggestion_cubit.dart';
import '../cubit/admin_suggestion_state.dart';

class AdminSuggestionFormPage extends StatefulWidget {
  final SuggestionEntity? existing;

  const AdminSuggestionFormPage({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  State<AdminSuggestionFormPage> createState() =>
      _AdminSuggestionFormPageState();
}

class _AdminSuggestionFormPageState extends State<AdminSuggestionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _secondsCtrl;
  late final TextEditingController _sortOrderCtrl;

  SuggestionContentType _contentType = SuggestionContentType.video;
  bool _isActive = true;
  String? _imageUrl;
  bool _uploadingImage = false;

  /// The YouTube video id [_imageUrl] is a thumbnail of, or null when the image
  /// is a custom upload / absent. Used to clear a stale thumbnail when the URL
  /// changes to a different video.
  String? _ytThumbVideoId;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _urlCtrl = TextEditingController(text: s?.contentUrl ?? '');
    _minutesCtrl = TextEditingController(
      text: s != null ? (s.durationSeconds ~/ 60).toString() : '',
    );
    _secondsCtrl = TextEditingController(
      text: s != null ? (s.durationSeconds % 60).toString() : '',
    );
    _sortOrderCtrl = TextEditingController(
      text: s?.sortOrder?.toString() ?? '',
    );
    _contentType = s?.contentType ?? SuggestionContentType.video;
    _isActive = s?.isActive ?? true;
    _imageUrl = s?.imageUrl;
    _ytThumbVideoId = _extractYtThumbId(_imageUrl);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminSuggestionCubit, AdminSuggestionState>(
      listener: (context, state) {
        if (state is AdminSuggestionMutationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEdit ? 'تم تحديث المقترح' : 'تم إضافة المقترح',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          if (mounted) Navigator.of(context).pop();
        } else if (state is AdminSuggestionError) {
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
        appBar: AppBar(
          title: Text(widget.isEdit ? 'تعديل المقترح' : 'مقترح جديد'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (required)
                _ImagePickerWidget(
                  imageUrl: _imageUrl,
                  uploading: _uploadingImage,
                  onPick: _pickImage,
                ),
                const SizedBox(height: AppSpacing.md),

                // Title (required)
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // Content type
                Text(
                  'نوع المحتوى',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<SuggestionContentType>(
                  segments: const [
                    ButtonSegment(
                      value: SuggestionContentType.video,
                      label: Text('فيديو'),
                      icon: Icon(Icons.play_circle_outline),
                    ),
                    ButtonSegment(
                      value: SuggestionContentType.audio,
                      label: Text('صوتي'),
                      icon: Icon(Icons.headphones),
                    ),
                  ],
                  selected: {_contentType},
                  onSelectionChanged: (s) =>
                      setState(() => _contentType = s.first),
                ),
                const SizedBox(height: AppSpacing.md),

                // Content URL (required, type-matched)
                TextFormField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: _contentType == SuggestionContentType.video
                        ? 'رابط يوتيوب *'
                        : 'رابط Google Drive *',
                    hintText: 'https://...',
                  ),
                  keyboardType: TextInputType.url,
                  validator: _validateUrl,
                  onChanged: _onUrlChanged,
                ),
                if (_canUseYoutubeThumbnail) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: _useYoutubeThumbnail,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('استخدم صورة الفيديو من يوتيوب'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                // Duration (minutes + seconds → duration_seconds)
                Text(
                  'المدة *',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minutesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'دقائق',
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validateMinutes,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _secondsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ثوانٍ',
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validateSeconds,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Sort order (optional)
                TextFormField(
                  controller: _sortOrderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ترتيب الظهور (اختياري)',
                    hintText: 'اترك فارغاً ليظهر في الآخر',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v.trim()) == null) {
                      return 'أدخل رقماً صحيحاً';
                    }
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
                const SizedBox(height: AppSpacing.xl),

                PrimaryButton(
                  label: widget.isEdit ? 'حفظ التعديلات' : 'إضافة المقترح',
                  isLoading: _uploadingImage,
                  onPressed: _uploadingImage ? null : _save,
                ),

                // Keyboard-aware spacer.
                SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canUseYoutubeThumbnail =>
      _contentType == SuggestionContentType.video &&
      VideoId.parseVideoId(_urlCtrl.text.trim()) != null;

  void _onUrlChanged(String value) {
    final newId = VideoId.parseVideoId(value.trim());
    // Clear a now-stale YouTube thumbnail (belongs to a different video).
    if (_ytThumbVideoId != null && _ytThumbVideoId != newId) {
      _imageUrl = null;
      _ytThumbVideoId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم مسح صورة الفيديو لتغيّر الرابط'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    // Refresh button visibility as the URL becomes valid/invalid.
    setState(() {});
  }

  void _useYoutubeThumbnail() {
    final id = VideoId.parseVideoId(_urlCtrl.text.trim());
    if (id == null) return;
    setState(() {
      _imageUrl = 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      _ytThumbVideoId = id;
    });
  }

  static String? _extractYtThumbId(String? url) {
    if (url == null) return null;
    return RegExp(r'img\.youtube\.com/vi/([^/]+)/').firstMatch(url)?.group(1);
  }

  String? _validateUrl(String? v) {
    final url = v?.trim() ?? '';
    if (url.isEmpty) return 'الرابط مطلوب';
    if (_contentType == SuggestionContentType.video) {
      if (VideoId.parseVideoId(url) == null) {
        return 'أدخل رابط يوتيوب صحيحاً';
      }
    } else {
      if (!_isDriveUrl(url)) {
        return 'أدخل رابط Google Drive صحيحاً';
      }
    }
    return null;
  }

  static bool _isDriveUrl(String url) {
    return RegExp(r'drive\.google\.com/.*(/d/|[?&]id=)').hasMatch(url);
  }

  String? _validateMinutes(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null; // seconds may carry the duration
    final m = int.tryParse(text);
    if (m == null || m < 0) return 'غير صحيح';
    return null;
  }

  String? _validateSeconds(String? v) {
    final text = v?.trim() ?? '';
    final s = text.isEmpty ? 0 : int.tryParse(text);
    if (s == null || s < 0 || s > 59) return '0 - 59';
    if (_totalSeconds() <= 0) return 'المدة مطلوبة';
    return null;
  }

  int _totalSeconds() {
    final m = int.tryParse(_minutesCtrl.text.trim()) ?? 0;
    final s = int.tryParse(_secondsCtrl.text.trim()) ?? 0;
    return m * 60 + s;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingImage = true);
    final url = await context.read<AdminSuggestionCubit>().uploadImageAndGetUrl(
      picked.path,
    );
    if (!mounted) return;
    setState(() {
      _uploadingImage = false;
      if (url != null) {
        _imageUrl = url;
        _ytThumbVideoId = null; // now a custom uploaded image
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الصورة مطلوبة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final sortOrderText = _sortOrderCtrl.text.trim();
    final sortOrder = sortOrderText.isEmpty ? null : int.parse(sortOrderText);

    final cubit = context.read<AdminSuggestionCubit>();
    if (widget.isEdit) {
      cubit.updateSuggestion(
        id: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        imageUrl: _imageUrl!,
        contentType: _contentType,
        contentUrl: _urlCtrl.text.trim(),
        durationSeconds: _totalSeconds(),
        sortOrder: sortOrder,
        isActive: _isActive,
      );
    } else {
      cubit.createSuggestion(
        title: _titleCtrl.text.trim(),
        imageUrl: _imageUrl!,
        contentType: _contentType,
        contentUrl: _urlCtrl.text.trim(),
        durationSeconds: _totalSeconds(),
        sortOrder: sortOrder,
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
                    'إضافة صورة المقترح *',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}
