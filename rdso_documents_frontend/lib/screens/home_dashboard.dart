import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import '../widgets/app_drawer.dart';
import '../services/document_service.dart';
import '../services/download_queue_service.dart';
import '../models/document.dart';
import '../models/category.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final DocumentService _documentService = DocumentService();
  List<Document> _documents = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dump = await _documentService.getDump();
    if (!mounted) return;
    setState(() {
      _documents = dump['documents'] as List<Document>;
      _categories = dump['categories'] as List<Category>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      sidebar: buildAppDrawer(context, categories: _categories),
      appBar: Ux4gAppBar(
        title: const Text(
          'Home Dashboard',
          style: TextStyle(
            fontSize: Ux4gTypography.sizeH4,
            fontWeight: Ux4gTypography.weightBold,
            color: Ux4gColors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Ux4gSpacing.sm),
            child: IconButton(
              icon: const Icon(Icons.notifications),
              color: Ux4gColors.primary,
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Ux4gSpacing.md),
            color: Ux4gColors.white,
            child: Ux4gTextField(
              hint: 'Search documents by name, drawing no...',
              prefixIcon: const Icon(Icons.search),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pushNamed(context, '/results', arguments: 'Search: $value');
                }
              },
            ),
          ),
          const Divider(height: 1),
          Consumer<DownloadQueueService>(
            builder: (context, queue, _) {
              if (queue.pendingCount == 0 && queue.activeCount == 0) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Ux4gSpacing.md,
                  vertical: Ux4gSpacing.sm,
                ),
                color: Ux4gColors.primary.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: Ux4gSpacing.sm),
                    Expanded(
                      child: Text(
                        'Downloading ${queue.activeCount + queue.pendingCount} document(s)...',
                        style: const TextStyle(
                          fontSize: Ux4gTypography.sizeSmall,
                          fontWeight: Ux4gTypography.weightSemiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? const Center(child: Text('No documents found'))
                    : ListView(
                        padding: const EdgeInsets.all(Ux4gSpacing.md),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: Ux4gSpacing.sm, left: Ux4gSpacing.xs),
                            child: Text(
                              'All Documents',
                              style: TextStyle(
                                fontSize: Ux4gTypography.sizeH5,
                                fontWeight: Ux4gTypography.weightSemiBold,
                              ),
                            ),
                          ),
                          ..._documents.map((doc) => Padding(
                            padding: const EdgeInsets.only(bottom: Ux4gSpacing.sm),
                            child: _buildDocumentCard(context, doc),
                          )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, Document doc) {
    final timeAgo = _formatTimeAgo(doc.lastUpdated);
    return Ux4gCard(
      onTap: () {
        Navigator.pushNamed(context, '/pdf', arguments: {
          'name': doc.name,
          'version': doc.version,
          'documentId': doc.documentId,
        });
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.picture_as_pdf, color: Ux4gColors.danger, size: 40),
          const SizedBox(width: Ux4gSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(
                    fontWeight: Ux4gTypography.weightSemiBold,
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
                const SizedBox(height: Ux4gSpacing.xs),
                Row(
                  children: [
                    Ux4gBadge(
                      label: doc.version,
                      variant: doc.version.toLowerCase() == 'archive'
                          ? Ux4gAlertVariant.warning
                          : Ux4gAlertVariant.success,
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Ux4gColors.gray500,
                        fontSize: Ux4gTypography.sizeSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} min ago';
    return 'just now';
  }
}
