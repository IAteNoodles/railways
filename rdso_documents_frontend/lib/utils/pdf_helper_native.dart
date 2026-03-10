import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Uint8List?> fetchPdfBytes(
    String url, Map<String, String> headers) async {
  debugPrint('[PDF Native] fetchPdfBytes: $url');
  final response = await http.get(Uri.parse(url), headers: headers);
  debugPrint('[PDF Native] fetchPdfBytes: status=${response.statusCode}, bytes=${response.bodyBytes.length}');
  if (response.statusCode == 200) return response.bodyBytes;
  return null;
}

Future<String> savePdfFile(Uint8List bytes, String fileName) async {
  Directory? baseDir;
  
  if (Platform.isAndroid) {
    if (await Permission.storage.request().isGranted || await Permission.manageExternalStorage.request().isGranted) {
      baseDir = Directory('/storage/emulated/0/RDSO/Downloads');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
    } else {
      // Fallback if permission denied
      baseDir = await getExternalStorageDirectory();
    }
  } else if (Platform.isWindows) {
    baseDir = await getDownloadsDirectory();
    if (baseDir != null) {
      baseDir = Directory('${baseDir.path}/RDSO');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
    }
  }

  if (baseDir == null) {
    baseDir = await getApplicationDocumentsDirectory();
  }

  final file = File('${baseDir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Widget buildPdfViewer(Uint8List bytes) {
  debugPrint('[PDF Native] buildPdfViewer: ${bytes.length} bytes, magic=${bytes.length > 4 ? String.fromCharCodes(bytes.sublist(0, 5)) : "too short"}');
  return SfPdfViewer.memory(
    bytes,
    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
      debugPrint('[PDF Native] SfPdfViewer FAILED: ${details.error}');
      debugPrint('[PDF Native] SfPdfViewer description: ${details.description}');
    },
    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
      debugPrint('[PDF Native] SfPdfViewer loaded: ${details.document.pages.count} pages');
    },
  );
}

Future<void> openPdfFile(String path) async {
  final uri = Uri.file(path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// Save bytes to a temp file and return the path (for sharing).
Future<String> savePdfToTemp(Uint8List bytes, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
