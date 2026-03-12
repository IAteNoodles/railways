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

  Widget _buildDocList(List<Document> docs) {
    if (docs.isEmpty) {
      return const Center(child: Text('No documents'));
    }
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.all(Ux4gSpacing.md),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: Ux4gSpacing.md),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final isSelected = _selectedIds.contains(doc.documentId);
          return GestureDetector(
            onLongPress: () {
              if (!_selectMode) setState(() => _selectMode = true);
              _toggleSelect(doc.documentId);
            },
            child: Ux4gCard(
              padding: const EdgeInsets.all(Ux4gSpacing.md),
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
                children: [
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: Ux4gSpacing.sm),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Ux4gColors.primary : Ux4gColors.gray400,
                      ),
                    ),
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
                        const SizedBox(height: Ux4gSpacing.xs),
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
                  if (!_selectMode)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Ux4gIconButton(
                          icon: const Icon(Icons.visibility),
                          tooltip: 'View',
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.pdf, arguments: {
                              'name': doc.name,
                              'version': doc.version,
                              'documentId': doc.documentId,
                              'documentUrl': doc.buildDocumentUrl(ApiConfig.baseUrl, download: false),
                              'contentType': doc.contentType,
                            });
                          },
                          variant: Ux4gButtonVariant.primary,
                          style: Ux4gButtonStyle.ghost,
                        ),
                        const SizedBox(height: Ux4gSpacing.xs),
                        Ux4gIconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Download',
                          onPressed: () => downloadDocument(context, doc),
                          variant: Ux4gButtonVariant.success,
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
