import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import '../services/catalog_service.dart';
import '../services/download_queue_service.dart';
import '../models/document.dart';
import '../utils/download_helper.dart';
import '../config/routes.dart';
import '../config/api_config.dart';

class DrawingListScreen extends StatefulWidget {
  const DrawingListScreen({super.key});

  @override
  State<DrawingListScreen> createState() => _DrawingListScreenState();
}

class _DrawingListScreenState extends State<DrawingListScreen>
    with SingleTickerProviderStateMixin {
  final CatalogService _catalogService = CatalogService();
  List<Document> _allDocs = [];
  bool _isLoading = true;
  int? _subheadId;
  String _subheadName = 'Drawings';
  late TabController _tabController;

  // Multi-select state
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) {
      final newId = arg['subheadId'] as int?;
      if (newId != null && newId != _subheadId) {
        _subheadId = newId;
        _subheadName = arg['subheadName'] as String? ?? 'Drawings';
        _loadDocuments();
      }
    }
  }

  Future<void> _loadDocuments() async {
    if (_subheadId == null) return;
    setState(() => _isLoading = true);
    final docs = await _catalogService.getDocumentsBySubhead(_subheadId!);
    if (!mounted) return;
    setState(() {
      _allDocs = docs;
      _isLoading = false;
    });
  }

  List<Document> get _currentDocs =>
      _allDocs.where((d) => !d.isArchived).toList();

  List<Document> get _archiveDocs =>
      _allDocs.where((d) => d.isArchived).toList();

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
    final tasks = _allDocs
        .where((d) => _selectedIds.contains(d.documentId))
      .map((d) => DownloadTask(
            documentId: d.documentId,
            name: d.name,
            fetchUrl: d.buildDocumentUrl(ApiConfig.baseUrl, download: true),
          ))
        .toList();
    context.read<DownloadQueueService>().enqueue(tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tasks.length} document(s) added to download queue')),
    );
    _exitSelectMode();
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      appBar: Ux4gAppBar(
        title: _selectMode
            ? Text('${_selectedIds.length} selected')
            : Text(_subheadName),
        leading: _selectMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectMode)
            : null,
        actions: _selectMode
            ? [IconButton(icon: const Icon(Icons.download), tooltip: 'Download selected', onPressed: _bulkDownload)]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Current (${_currentDocs.length})'),
            Tab(text: 'Archive (${_archiveDocs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDocList(_currentDocs),
                _buildDocList(_archiveDocs),
              ],
            ),
    );
  }

  /// Returns file type info (label, icon, color) based on contentType.
  ({String label, IconData icon, Color color}) _fileTypeInfo(String? contentType) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('pdf')) {
      return (label: 'PDF', icon: Icons.picture_as_pdf_rounded, color: Colors.red.shade600);
    } else if (ct.contains('png')) {
      return (label: 'PNG', icon: Icons.image_rounded, color: Colors.teal.shade600);
    } else if (ct.contains('jpg') || ct.contains('jpeg')) {
      return (label: 'JPG', icon: Icons.image_rounded, color: Colors.orange.shade700);
    } else if (ct.contains('tif')) {
      return (label: 'TIFF', icon: Icons.image_rounded, color: Colors.indigo.shade400);
    } else if (ct.contains('dwg') || ct.contains('autocad')) {
      return (label: 'DWG', icon: Icons.architecture_rounded, color: Colors.blue.shade700);
    } else if (ct.contains('word') || ct.contains('doc')) {
      return (label: 'DOC', icon: Icons.description_rounded, color: Colors.blue.shade600);
    } else if (ct.contains('excel') || ct.contains('spreadsheet') || ct.contains('xls')) {
      return (label: 'XLS', icon: Icons.table_chart_rounded, color: Colors.green.shade700);
    } else {
      return (label: 'FILE', icon: Icons.insert_drive_file_rounded, color: Ux4gColors.gray500);
    }
  }

  Widget _buildDocList(List<Document> docs) {
    if (docs.isEmpty) {
      return const Center(child: Text('No documents'));
    }
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.all(Ux4gSpacing.md),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: Ux4gSpacing.sm),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final isSelected = _selectedIds.contains(doc.documentId);
          final fileInfo = _fileTypeInfo(doc.contentType);
          return GestureDetector(
            onLongPress: () {
              if (!_selectMode) setState(() => _selectMode = true);
              _toggleSelect(doc.documentId);
            },
            child: Ux4gCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Ux4gSpacing.md,
                vertical: Ux4gSpacing.sm,
              ),
              onTap: _selectMode
                  ? () => _toggleSelect(doc.documentId)
                  : () {
                      Navigator.pushNamed(context, AppRoutes.pdf, arguments: {
                        'name': doc.name,
                        'version': doc.version,
                        'documentId': doc.documentId,
                        'documentUrl': doc.buildDocumentUrl(ApiConfig.baseUrl, download: false),
                        'contentType': doc.contentType,
                      });
                    },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Selection checkbox or file-type badge
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: Ux4gSpacing.sm),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Ux4gColors.primary : Ux4gColors.gray400,
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: Ux4gSpacing.sm),
                      decoration: BoxDecoration(
                        color: fileInfo.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(fileInfo.icon, size: 20, color: fileInfo.color),
                          const SizedBox(height: 1),
                          Text(
                            fileInfo.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: fileInfo.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Document info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          style: const TextStyle(
                            fontWeight: Ux4gTypography.weightBold,
                            fontSize: Ux4gTypography.sizeBody1,
                          ),
                        ),
                        const SizedBox(height: Ux4gSpacing.xxs),
                        Text(
                          'Drawing No: ${doc.documentId}',
                          style: const TextStyle(
                            color: Ux4gColors.gray600,
                            fontSize: Ux4gTypography.sizeSmall,
                          ),
                        ),
                        if (doc.description != null && doc.description!.isNotEmpty) ...[
                          const SizedBox(height: Ux4gSpacing.xxs),
                          Text(
                            doc.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Ux4gColors.gray500,
                              fontSize: Ux4gTypography.sizeSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons – side by side
                  if (!_selectMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility_outlined, color: Ux4gColors.primary, size: 21),
                          tooltip: 'View',
                          splashRadius: 20,
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.pdf, arguments: {
                              'name': doc.name,
                              'version': doc.version,
                              'documentId': doc.documentId,
                              'documentUrl': doc.buildDocumentUrl(ApiConfig.baseUrl, download: false),
                              'contentType': doc.contentType,
                            });
                          },
                        ),
                        const SizedBox(width: Ux4gSpacing.xxs),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, color: Colors.green, size: 21),
                          tooltip: 'Download',
                          splashRadius: 20,
                          onPressed: () => downloadDocument(context, doc),
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
