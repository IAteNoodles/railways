import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import '../services/document_service.dart';
import '../services/download_queue_service.dart';
import '../models/document.dart';
import '../utils/pdf_helper.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class CategoryResultsScreen extends StatefulWidget {
  const CategoryResultsScreen({super.key});

  @override
  State<CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<CategoryResultsScreen> {
  final DocumentService _documentService = DocumentService();
  List<Document> _documents = [];
  bool _isLoading = true;
  String _title = 'Results';

  // Multi-select state
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _title = ModalRoute.of(context)?.settings.arguments as String? ?? 'Results';
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    List<Document> docs;
    if (_title.startsWith('Search: ')) {
      final query = _title.substring(8);
      docs = await _documentService.searchDocuments(query);
    } else if (_title == 'All Documents') {
      docs = await _documentService.getDocuments();
    } else {
      docs = await _documentService.getDocumentsByCategory(_title);
    }

    if (!mounted) return;
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  void _toggleSelect(String docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _bulkDownload() {
    if (_selectedIds.isEmpty) return;

    final tasks = _documents
        .where((d) => _selectedIds.contains(d.documentId))
        .map((d) => DownloadTask(documentId: d.documentId, name: d.name))
        .toList();

    context.read<DownloadQueueService>().enqueue(tasks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tasks.length} document(s) added to download queue'),
      ),
    );

    _exitSelectMode();
  }

  Future<void> _downloadDoc(Document doc) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading...')),
    );

    try {
      final headers = await ApiService().authHeaders();
      final url =
          '${ApiConfig.baseUrl}/documents/?document_ids=${doc.documentId}&download=true';
      final bytes = await fetchPdfBytes(url, headers);
      if (!mounted) return;

      if (bytes != null && bytes.isNotEmpty) {
        final path = await savePdfFile(bytes, '${doc.documentId}.pdf');
        if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      appBar: Ux4gAppBar(
        title: _selectMode
            ? Text('${_selectedIds.length} selected')
            : Text(_title),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: _selectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download selected',
                  onPressed: _bulkDownload,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('No documents found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(Ux4gSpacing.md),
                  itemCount: _documents.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: Ux4gSpacing.md),
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final isArchive =
                        doc.version.toLowerCase() == 'archive';
                    final isSelected =
                        _selectedIds.contains(doc.documentId);
                    return GestureDetector(
                      onLongPress: () {
                        if (!_selectMode) {
                          setState(() => _selectMode = true);
                        }
                        _toggleSelect(doc.documentId);
                      },
                      child: Ux4gCard(
                      padding: const EdgeInsets.all(Ux4gSpacing.md),
                      onTap: _selectMode
                          ? () => _toggleSelect(doc.documentId)
                          : () {
                              Navigator.pushNamed(context, '/pdf',
                                  arguments: {
                                    'name': doc.name,
                                    'version': doc.version,
                                    'documentId': doc.documentId,
                                  });
                            },
                      child: Row(
                        children: [
                          if (_selectMode)
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: Ux4gSpacing.sm),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? Ux4gColors.primary
                                    : Ux4gColors.gray400,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.name,
                                  style: const TextStyle(
                                    fontWeight:
                                        Ux4gTypography.weightBold,
                                    fontSize:
                                        Ux4gTypography.sizeBody1,
                                  ),
                                ),
                                const SizedBox(
                                    height: Ux4gSpacing.xs),
                                Text(
                                  'Drawing No: ${doc.documentId}',
                                  style: const TextStyle(
                                    color: Ux4gColors.gray600,
                                    fontSize:
                                        Ux4gTypography.sizeSmall,
                                  ),
                                ),
                                const SizedBox(
                                    height: Ux4gSpacing.xs),
                                Ux4gBadge(
                                  label: isArchive
                                      ? 'Archive'
                                      : doc.version,
                                  variant: isArchive
                                      ? Ux4gAlertVariant.warning
                                      : Ux4gAlertVariant.success,
                                ),
                              ],
                            ),
                          ),
                          if (!_selectMode)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Ux4gIconButton(
                                  icon:
                                      const Icon(Icons.visibility),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/pdf',
                                        arguments: {
                                          'name': doc.name,
                                          'version': doc.version,
                                          'documentId':
                                              doc.documentId,
                                        });
                                  },
                                  variant:
                                      Ux4gButtonVariant.primary,
                                  style: Ux4gButtonStyle.ghost,
                                ),
                                const SizedBox(
                                    height: Ux4gSpacing.xs),
                                Ux4gIconButton(
                                  icon:
                                      const Icon(Icons.download),
                                  onPressed: () =>
                                      _downloadDoc(doc),
                                  variant:
                                      Ux4gButtonVariant.success,
                                  style: Ux4gButtonStyle.ghost,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    );
                  },
                ),
    );
  }
}
