import 'package:flutter/material.dart';
import 'package:ux4g/ux4g.dart';
import '../services/catalog_service.dart';
import '../models/subhead.dart';
import '../config/routes.dart';
import '../utils/category_navigation.dart';
import '../models/category.dart';

class SubheadListScreen extends StatefulWidget {
  const SubheadListScreen({super.key});

  @override
  State<SubheadListScreen> createState() => _SubheadListScreenState();
}

class _SubheadListScreenState extends State<SubheadListScreen> {
  final CatalogService _catalogService = CatalogService();
  List<Subhead> _subheads = [];
  bool _isLoading = true;
  int? _categoryId;
  String _categoryName = 'Subheads';
  int _drawingCount = 0;
  int _subheadCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) {
      final newId = arg['categoryId'] as int?;
      if (newId != null && newId != _categoryId) {
        _categoryId = newId;
        _categoryName = arg['categoryName'] as String? ?? 'Subheads';
        _drawingCount = arg['drawingCount'] as int? ?? 0;
        _subheadCount = arg['subheadCount'] as int? ?? 0;
        _loadSubheads();
      }
    }
  }

  Future<void> _loadSubheads() async {
    if (_categoryId == null) return;
    setState(() => _isLoading = true);
    final subheads = await _catalogService.getSubheads(_categoryId!);
    if (!mounted) return;
    setState(() {
      _subheads = subheads;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      appBar: Ux4gAppBar(
        title: Text(_categoryName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subheads.isEmpty
            ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadSubheads,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Ux4gSpacing.md),
                    itemCount: _subheads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Ux4gSpacing.sm),
                    itemBuilder: (context, index) {
                      final sub = _subheads[index];
                      return Ux4gCard(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.drawings, arguments: {
                            'subheadId': sub.id,
                            'subheadName': sub.name,
                          });
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open, color: Ux4gColors.primary, size: 36),
                            const SizedBox(width: Ux4gSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.name,
                                    style: const TextStyle(
                                      fontWeight: Ux4gTypography.weightSemiBold,
                                      fontSize: Ux4gTypography.sizeBody1,
                                    ),
                                  ),
                                  const SizedBox(height: Ux4gSpacing.xxs),
                                  Text(
                                    '${sub.drawingCount} drawing(s)',
                                    style: const TextStyle(
                                      color: Ux4gColors.gray500,
                                      fontSize: Ux4gTypography.sizeSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Ux4gColors.gray400),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasDirectDrawings = _drawingCount > 0 && _subheadCount == 0;

    if (!hasDirectDrawings) {
      return const Center(child: Text('No subheads found'));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Ux4gSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 56,
              color: Ux4gColors.primary,
            ),
            const SizedBox(height: Ux4gSpacing.md),
            Text(
              '$_categoryName has direct drawings and no subheads.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: Ux4gTypography.sizeBody1,
                fontWeight: Ux4gTypography.weightSemiBold,
              ),
            ),
            const SizedBox(height: Ux4gSpacing.sm),
            Text(
              'Open $_drawingCount drawing(s)',
              style: const TextStyle(
                color: Ux4gColors.gray600,
                fontSize: Ux4gTypography.sizeSmall,
              ),
            ),
            const SizedBox(height: Ux4gSpacing.md),
            Ux4gButton(
              onPressed: () {
                openCategory(
                  context,
                  Category(
                    id: _categoryId!,
                    name: _categoryName,
                    subheadCount: 0,
                    drawingCount: _drawingCount,
                  ),
                );
              },
              child: const Text('Open Drawings'),
            ),
          ],
        ),
      ),
    );
  }
}
