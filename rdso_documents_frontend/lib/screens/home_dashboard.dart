import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import '../widgets/app_drawer.dart';
import '../services/catalog_service.dart';
import '../services/download_queue_service.dart';
import '../models/category.dart';
import '../config/routes.dart';
import '../utils/category_icons.dart';
import '../utils/category_navigation.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final CatalogService _catalogService = CatalogService();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _catalogService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Ux4gScaffold(
      sidebar: buildAppDrawer(context, categories: _categories),
      appBar: Ux4gAppBar(
        title: const Text(
          'RDSO Drawing Catalog',
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
              tooltip: 'Notifications',
              color: Ux4gColors.primary,
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.notifications);
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
                  Navigator.pushNamed(context, AppRoutes.results, arguments: 'Search: $value');
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
                : _categories.isEmpty
                    ? const Center(child: Text('No categories found'))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(Ux4gSpacing.md),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            childAspectRatio: 1.3,
                            crossAxisSpacing: Ux4gSpacing.md,
                            mainAxisSpacing: Ux4gSpacing.md,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            return _buildCategoryCard(context, _categories[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category cat) {
    return Ux4gCard(
      onTap: () {
        openCategory(context, cat);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconForCategory(cat.name),
            size: 40,
            color: Ux4gColors.primary,
          ),
          const SizedBox(height: Ux4gSpacing.sm),
          Text(
            cat.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: Ux4gTypography.weightSemiBold,
              fontSize: Ux4gTypography.sizeBody1,
            ),
          ),
          const SizedBox(height: Ux4gSpacing.xs),
          Text(
            '${cat.drawingCount ?? 0} drawings',
            style: const TextStyle(
              color: Ux4gColors.gray500,
              fontSize: Ux4gTypography.sizeSmall,
            ),
          ),
        ],
      ),
    );
  }
}
