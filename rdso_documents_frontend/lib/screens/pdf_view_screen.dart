import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:ux4g/ux4g.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../models/post.dart';
import '../utils/pdf_helper.dart';
import '../utils/date_utils.dart' as app_dates;

class PdfViewScreen extends StatefulWidget {
  const PdfViewScreen({super.key});

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  final PostService _postService = PostService();
  List<Post> _feedback = [];
  bool _isLoadingFeedback = false;
  String? _documentId;
  String? _documentUrl;
  String _name = 'Document';
  String _version = 'Current';
  String _contentType = 'application/pdf';
  bool _showFeedback = false;
  String? _pdfUrl;
  bool _pdfError = false;
  Uint8List? _pdfBytes;
  bool _isLoadingPdf = false;
  String? _pdfErrorMessage;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) {
      _name = arg['name'] ?? _name;
      _version = arg['version'] ?? _version;
      _documentId = arg['documentId'];
      _documentUrl = arg['documentUrl'];
      _contentType = arg['contentType'] ?? 'application/pdf';
    }
    if (_documentId != null) {
      _initialized = true;
      _pdfUrl = _documentUrl ?? '${ApiConfig.baseUrl}/documents/?document_ids=$_documentId&download=false';
      _loadPdf();
      _loadFeedback();
    }
  }

  Future<void> _loadPdf() async {
    if (_documentId == null) return;
    setState(() {
      _isLoadingPdf = true;
      _pdfError = false;
      _pdfErrorMessage = null;
    });
    try {
      final headers = await ApiService().authHeaders();
      final url = _documentUrl ?? '${ApiConfig.baseUrl}/documents/?document_ids=$_documentId&download=false';
      if (kDebugMode) debugPrint('[PdfViewScreen] _loadPdf: fetching $url');
      final bytes = await fetchPdfBytes(url, headers);
      if (!mounted) return;
      if (kDebugMode) debugPrint('[PdfViewScreen] _loadPdf: received ${bytes?.length ?? 0} bytes');
      if (bytes != null && bytes.length > 4) {
        // Check if this is a PDF by magic number, or an image by content type
        final isPdf = bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
        final isImage = _contentType.startsWith('image/');
        if (kDebugMode) debugPrint('[PdfViewScreen] _loadPdf: isPdf=$isPdf, isImage=$isImage, contentType=$_contentType');

        if (isPdf || isImage) {
          setState(() {
            _pdfBytes = bytes;
            _isLoadingPdf = false;
          });
        } else {
          // Server returned unexpected content
          if (kDebugMode) {
            final text = String.fromCharCodes(bytes.take(200));
            debugPrint('[PdfViewScreen] unexpected response: $text');
          }
          setState(() {
            _pdfError = true;
            _pdfErrorMessage = 'Unable to load document. Please try again later.';
            _isLoadingPdf = false;
          });
        }
      } else {
        setState(() {
          _pdfError = true;
          _pdfErrorMessage = 'Failed to load PDF data';
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('[PdfViewScreen] _loadPdf error: $e');
      setState(() {
        _pdfError = true;
        _pdfErrorMessage = 'An unexpected error occurred while loading the document.';
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _loadFeedback() async {
    if (_documentId == null) return;
    setState(() => _isLoadingFeedback = true);
    final feedback = await _postService.getFeedback(_documentId!);
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _isLoadingFeedback = false;
    });
  }

  Future<void> _showAddFeedbackDialog() async {
    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document ID not available')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter your feedback...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final post = await _postService.createPost(
        documentId: _documentId!,
        content: result.trim(),
        postType: 'feedback',
      );
      if (!mounted) return;
      if (post != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted')),
        );
        _loadFeedback();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit feedback')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_documentId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading...')),
    );

    try {
      final headers = await ApiService().authHeaders();
      final url = _documentUrl == null
        ? '${ApiConfig.baseUrl}/documents/?document_ids=$_documentId&download=true'
        : _documentUrl!.replaceFirst('download=false', 'download=true');
      final bytes = await fetchPdfBytes(url, headers);
      if (!mounted) return;

      if (bytes != null && bytes.isNotEmpty) {
        final ext = _extensionForContentType(_contentType);
        final fileName = '$_documentId$ext';
        final path = await savePdfFile(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
                ? '$fileName downloaded'
                : '$fileName downloaded at $path'),
            duration: const Duration(seconds: 5),
            action: kIsWeb
                ? null
                : SnackBarAction(
                    label: 'Open',
                    onPressed: () => openPdfFile(path),
                  ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('[PdfViewScreen] download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed. Please try again.')),
      );
    }
  }

  Future<void> _sharePdf() async {
    if (_documentId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing to share...')),
    );

    try {
      final headers = await ApiService().authHeaders();
      final url = _documentUrl == null
        ? '${ApiConfig.baseUrl}/documents/?document_ids=$_documentId&download=true'
        : _documentUrl!.replaceFirst('download=false', 'download=true');
      final bytes = await fetchPdfBytes(url, headers);
      if (!mounted) return;

      if (bytes != null && bytes.isNotEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();

        if (kIsWeb) {
          // On web, just trigger a download
          await savePdfFile(bytes, '$_documentId${_extensionForContentType(_contentType)}');
          return;
        }

        // Save to temp dir for sharing
        final fileName = '$_documentId${_extensionForContentType(_contentType)}';
        final tempPath = await savePdfToTemp(bytes, fileName);

        await Share.shareXFiles(
          [XFile(tempPath)],
          text: _name,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load PDF for sharing')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('[PdfViewScreen] share error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share document. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      backgroundColor: Ux4gColors.gray100,
      appBar: Ux4gAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _name,
              style: const TextStyle(fontSize: Ux4gTypography.sizeBody1, fontWeight: Ux4gTypography.weightBold),
            ),
            Text(
              '($_version)',
              style: const TextStyle(fontSize: Ux4gTypography.sizeSmall, fontWeight: Ux4gTypography.weightRegular, color: Ux4gColors.gray600),
            ),
          ],
        ),
        actions: [
          if (_documentId != null)
            IconButton(
              icon: Icon(_showFeedback ? Icons.picture_as_pdf : Icons.chat),
              onPressed: () => setState(() => _showFeedback = !_showFeedback),
              tooltip: _showFeedback ? 'Show PDF' : 'Show Feedback',
            ),
        ],
      ),
      body: _showFeedback ? _buildFeedbackList() : _buildPdfViewer(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Ux4gColors.white,
          border: Border(top: BorderSide(color: Ux4gColors.borderColor)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(
            horizontal: Ux4gSpacing.sm,
            vertical: Ux4gSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Ux4gButton(
                  onPressed: _showAddFeedbackDialog,
                  variant: Ux4gButtonVariant.primary,
                  style: Ux4gButtonStyle.outline,
                  size: Ux4gButtonSize.sm,
                  icon: const Icon(Icons.feedback, size: 16),
                  child: const Text('Feedback'),
                ),
              ),
              const SizedBox(width: Ux4gSpacing.xs),
              Expanded(
                child: Ux4gButton(
                  onPressed: _sharePdf,
                  variant: Ux4gButtonVariant.primary,
                  style: Ux4gButtonStyle.outline,
                  size: Ux4gButtonSize.sm,
                  icon: const Icon(Icons.share, size: 16),
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(width: Ux4gSpacing.xs),
              Expanded(
                child: Ux4gButton(
                  onPressed: _downloadPdf,
                  variant: Ux4gButtonVariant.primary,
                  size: Ux4gButtonSize.sm,
                  icon: const Icon(Icons.download, size: 16),
                  child: const Text('Download'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (_pdfUrl == null) {
      return const Center(child: Text('No document selected'));
    }
    if (_isLoadingPdf) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pdfError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Ux4gColors.gray400),
            const SizedBox(height: Ux4gSpacing.md),
            Text(
              'Failed to load PDF\n${_pdfErrorMessage ?? ""}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Ux4gColors.gray500),
            ),
            const SizedBox(height: Ux4gSpacing.sm),
            Ux4gButton(
              onPressed: _loadPdf,
              variant: Ux4gButtonVariant.primary,
              style: Ux4gButtonStyle.outline,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_pdfBytes == null) {
      return const Center(child: Text('No document data'));
    }

    // Render image files directly
    if (_contentType.startsWith('image/')) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(_pdfBytes!, fit: BoxFit.contain),
        ),
      );
    }

    return buildPdfViewer(_pdfBytes!);
  }

  Widget _buildFeedbackList() {
    if (_isLoadingFeedback) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedback.isEmpty) {
      return const Center(child: Text('No feedback yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Ux4gSpacing.md),
      itemCount: _feedback.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final post = _feedback[index];
        return Ux4gCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Ux4gColors.gray600),
                  const SizedBox(width: Ux4gSpacing.xs),
                  Text(
                    post.userHrmsId,
                    style: const TextStyle(
                      fontWeight: Ux4gTypography.weightSemiBold,
                      fontSize: Ux4gTypography.sizeSmall,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(post.createdAt),
                    style: const TextStyle(
                      color: Ux4gColors.gray500,
                      fontSize: Ux4gTypography.sizeSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Ux4gSpacing.sm),
              Text(post.content),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return app_dates.formatDate(dt);
  }

  String _extensionForContentType(String ct) {
    switch (ct) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return '.pdf';
    }
  }
}
