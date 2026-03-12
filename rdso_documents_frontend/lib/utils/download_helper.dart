import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/document.dart';
import '../services/api_service.dart';
import 'pdf_helper.dart';

/// Downloads a document PDF and shows appropriate snackbar feedback.
/// Must be called from a State with a valid BuildContext.
Future<void> downloadDocument(BuildContext context, Document doc) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Downloading...')),
  );

  try {
    final headers = await ApiService().authHeaders();
    final url = doc.buildDocumentUrl(ApiConfig.baseUrl, download: true);
    final bytes = await fetchPdfBytes(url, headers);

    if (!context.mounted) return;

    if (bytes != null && bytes.isNotEmpty) {
      final path = await savePdfFile(bytes, '${doc.documentId}.pdf');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'Download started'
              : '${doc.documentId}.pdf saved'),
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download error: $e')),
    );
  }
}
