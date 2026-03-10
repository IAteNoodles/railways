import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _viewCounter = 0;

Future<Uint8List?> fetchPdfBytes(
    String url, Map<String, String> headers) async {
  final request = await html.HttpRequest.request(
    url,
    method: 'GET',
    requestHeaders: headers,
    responseType: 'arraybuffer',
  );
  if (request.status == 200) {
    final buffer = request.response as ByteBuffer;
    return buffer.asUint8List();
  }
  return null;
}

Future<String> savePdfFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}

Widget buildPdfViewer(Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  final viewType = 'pdf-viewer-${_viewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = blobUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
  });
  return HtmlElementView(viewType: viewType);
}

Future<void> openPdfFile(String path) async {
  // On web, files are auto-downloaded by the browser — no-op
}

Future<String> savePdfToTemp(Uint8List bytes, String fileName) async {
  return '';
}
