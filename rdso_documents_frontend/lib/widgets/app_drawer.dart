import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import '../services/auth_service.dart';
import '../models/category.dart';
import '../config/routes.dart';
import '../utils/category_icons.dart';
import '../utils/category_navigation.dart';

Ux4gSidebar buildAppDrawer(BuildContext context, {List<Category> categories = const []}) {
  final auth = context.read<AuthService>();
  final user = auth.currentUser;
  final isAdmin = auth.isAdmin;

  return Ux4gSidebar(
      header: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Ux4gSpacing.lg, vertical: Ux4gSpacing.xl),
        color: Ux4gColors.primary.withValues(alpha: 0.1),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isAdmin ? Ux4gColors.warning : Ux4gColors.primary,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: Ux4gColors.white,
              ),
            ),
            const SizedBox(width: Ux4gSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HRMS ID: ${user?.hrmsId ?? "—"}',
                  style: const TextStyle(
                    fontWeight: Ux4gTypography.weightBold,
                    fontSize: Ux4gTypography.sizeBody1,
                  ),
                ),
                Text(
                  isAdmin ? 'Administrator' : 'RDSO Employee',
                  style: TextStyle(
                    color: isAdmin ? Ux4gColors.warning : Ux4gColors.gray600,
                    fontSize: Ux4gTypography.sizeSmall,
                    fontWeight: isAdmin ? Ux4gTypography.weightSemiBold : Ux4gTypography.weightRegular,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
        padding: const EdgeInsets.all(Ux4gSpacing.md),
        child: Ux4gButton(
          onPressed: () async {
            await auth.logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          },
          variant: Ux4gButtonVariant.danger,
          style: Ux4gButtonStyle.outline,
          isFullWidth: true,
          icon: const Icon(Icons.logout),
          child: const Text('Logout'),
        ),
      ),
      ),
      children: [
        ...categories.map((cat) => Ux4gSidebarItem(
          title: '${cat.name} (${cat.drawingCount ?? 0})',
          icon: Icon(iconForCategory(cat.name)),
          onTap: () {
            openCategory(context, cat);
          },
        )),
        Ux4gSidebarItem(
          title: 'All Documents',
          icon: const Icon(Icons.folder),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.results, arguments: 'All Documents');
          },
        ),
        if (isAdmin) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Ux4gSpacing.lg, vertical: Ux4gSpacing.xs),
            child: Text(
              'ADMIN',
              style: TextStyle(
                fontSize: Ux4gTypography.sizeSmall,
                fontWeight: Ux4gTypography.weightBold,
                color: Ux4gColors.warning.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Ux4gSidebarItem(
            title: 'User Management',
            icon: const Icon(Icons.people),
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers),
          ),
          Ux4gSidebarItem(
            title: 'Create Document',
            icon: const Icon(Icons.note_add),
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminCreateDocument, arguments: categories),
          ),
          Ux4gSidebarItem(
            title: 'RDSO Crawler',
            icon: const Icon(Icons.sync),
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminCrawler),
          ),
          Ux4gSidebarItem(
            title: 'Audit Logs',
            icon: const Icon(Icons.history),
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminLogs),
          ),
        ],
      ],
    );
}
