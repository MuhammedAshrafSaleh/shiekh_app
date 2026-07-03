// lib/features/lesson/widgets/pdf_tab.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/drive_url.dart';

class PdfTab extends StatefulWidget {
  final String pdfUrl;

  const PdfTab({super.key, required this.pdfUrl});

  @override
  State<PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<PdfTab> {
  PdfControllerPinch? _controller;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (mounted) setState(() { _hasError = false; _isLoading = true; });
    try {
      final downloadUrl = toDirectDownloadUrl(widget.pdfUrl);
      final response = await Dio().get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() { _hasError = true; _isLoading = false; });
        return;
      }

      final uint8Bytes = Uint8List.fromList(bytes);
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(uint8Bytes),
      );

      if (mounted) {
        _controller?.dispose();
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
      } else {
        controller.dispose();
      }
    } catch (_) {
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError || _controller == null) {
      return _PdfError(onRetry: _loadPdf);
    }

    return PdfViewPinch(
      controller: _controller!,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        errorBuilder: (ctx, err) => _PdfError(onRetry: _loadPdf),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PdfError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PdfError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'تعذّر تحميل ملف PDF',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'يرجى التواصل مع الإدارة لمراجعة الرابط',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
