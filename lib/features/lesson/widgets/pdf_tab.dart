// lib/features/lesson/widgets/pdf_tab.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/drive_url.dart';

class PdfTab extends StatefulWidget {
  final String pdfUrl;

  const PdfTab({super.key, required this.pdfUrl});

  @override
  State<PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<PdfTab> {
  static final _log = Logger('PdfTab');

  PdfControllerPinch? _controller;
  Uint8List? _pdfBytes;
  bool _hasError = false;
  bool _isLoading = true;
  bool _isSharing = false;
  // Null → show the default "check the link" hint; set for a network/timeout
  // failure so we don't wrongly blame the link.
  String? _errorHint;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
        _errorHint = null;
      });
    }
    try {
      final downloadUrl = toDirectDownloadUrl(widget.pdfUrl);
      final response =
          await Dio(
            BaseOptions(
              // Guard against a stalled connection hanging the load forever.
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ).get<List<int>>(
            downloadUrl,
            options: Options(responseType: ResponseType.bytes),
          );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        _log.warning('PDF download returned no bytes: ${widget.pdfUrl}');
        _fail();
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
          _pdfBytes = uint8Bytes;
          _isLoading = false;
        });
      } else {
        controller.dispose();
      }
    } on DioException catch (e) {
      // Network/timeout failure — log specifics and show a connectivity hint
      // rather than wrongly blaming the link.
      _log.warning(
        'PDF download failed (${e.type}) for ${widget.pdfUrl}: ${e.message}',
      );
      final isNetwork = e.type != DioExceptionType.badResponse;
      _fail(
        hint: isNetwork
            ? 'تعذّر الاتصال، تحقّق من الإنترنت وأعد المحاولة'
            : null,
      );
    } catch (e, st) {
      // Broad by design: PdfDocument.openData throws assorted non-Dio errors on
      // a corrupt/non-PDF payload; a bad file must never crash the lesson screen.
      _log.warning('PDF load failed for ${widget.pdfUrl}: $e', e, st);
      _fail();
    }
  }

  void _fail({String? hint}) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorHint = hint;
      });
    }
  }

  Future<void> _sharePdf() async {
    final bytes = _pdfBytes;
    if (bytes == null || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      await Printing.sharePdf(bytes: bytes, filename: 'lesson.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر مشاركة الملف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
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
      return _PdfError(onRetry: _loadPdf, hint: _errorHint);
    }

    return Stack(
      children: [
        PdfViewPinch(
          controller: _controller!,
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            errorBuilder: (ctx, err) => _PdfError(onRetry: _loadPdf),
            pageLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
        ),
        if (_pdfBytes != null)
          PositionedDirectional(
            end: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: _isSharing ? null : _sharePdf,
              tooltip: 'تحميل أو مشاركة الملف',
              child: _isSharing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
            ),
          ),
      ],
    );
  }
}

class _PdfError extends StatelessWidget {
  final VoidCallback onRetry;
  final String? hint;
  const _PdfError({required this.onRetry, this.hint});

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
          const Text('تعذّر تحميل ملف PDF', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint ?? 'يرجى التواصل مع الإدارة لمراجعة الرابط',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
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
