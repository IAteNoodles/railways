import 'category.dart';

class Document {
  final String documentId;
  final String name;
  final String version;
  final String link;
  final String internalLink;
  final List<Category> categories;
  final DateTime lastUpdated;
  final int? drawingId;
  final String? description;
  final String? contentType;
  final int? fileSize;
  final bool isArchived;
  final int? subheadId;

  Document({
    required this.documentId,
    required this.name,
    required this.version,
    required this.link,
    required this.internalLink,
    required this.categories,
    required this.lastUpdated,
    this.drawingId,
    this.description,
    this.contentType,
    this.fileSize,
    this.isArchived = false,
    this.subheadId,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      documentId: json['document_id'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? 'Current',
      link: json['link'] ?? '',
      internalLink: json['internal_link'] ?? '',
      categories: (json['category'] as List? ?? [])
          .map((c) => Category.fromJson(c))
          .toList(),
      lastUpdated: DateTime.parse(json['last_updated']),
      drawingId: json['drawing_id'],
      description: json['description'],
      contentType: json['content_type'],
      fileSize: json['file_size'],
      isArchived: json['is_archived'] ?? false,
      subheadId: json['subhead'],
    );
  }

  String get fetchDocumentId {
    final fromInternalLink = _documentIdFromInternalLink;
    if (fromInternalLink != null && fromInternalLink.isNotEmpty) {
      return fromInternalLink;
    }
    if (drawingId != null) {
      return drawingId.toString();
    }
    return documentId;
  }

  String buildDocumentUrl(String baseUrl, {required bool download}) {
    if (internalLink.isNotEmpty) {
      final internalUri = Uri.tryParse(internalLink);
      if (internalUri != null) {
        final resolvedUri = internalUri.hasScheme
            ? internalUri
            : Uri.parse(baseUrl).resolveUri(internalUri);

        if (resolvedUri.path.endsWith('/documents/') &&
            resolvedUri.queryParameters.containsKey('document_ids')) {
          final updatedParameters = Map<String, String>.from(
            resolvedUri.queryParameters,
          );
          updatedParameters['download'] = download.toString();
          return resolvedUri.replace(queryParameters: updatedParameters).toString();
        }

        return resolvedUri.toString();
      }
    }

    return '${baseUrl}/documents/?document_ids=$fetchDocumentId&download=${download.toString()}';
  }

  String? get _documentIdFromInternalLink {
    if (internalLink.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(internalLink);
    return uri?.queryParameters['document_ids'];
  }
}
