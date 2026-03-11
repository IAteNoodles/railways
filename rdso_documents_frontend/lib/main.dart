import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ux4g/ux4g.dart';
import 'services/auth_service.dart';
import 'services/download_queue_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/category_results_screen.dart';
import 'screens/pdf_view_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/create_document_screen.dart';
import 'screens/admin/audit_logs_screen.dart';
import 'widgets/admin_guard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => DownloadQueueService()..init()),
      ],
      child: const RdsoDocumentsApp(),
    ),
  );
}

class RdsoDocumentsApp extends StatelessWidget {
  const RdsoDocumentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDSO Documents',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Ux4gColors.primary),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeDashboard(),
        '/results': (context) => const CategoryResultsScreen(),
        '/pdf': (context) => const PdfViewScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/admin/users': (context) => const AdminGuard(child: UserManagementScreen()),
        '/admin/create-document': (context) => const AdminGuard(child: CreateDocumentScreen()),
        '/admin/logs': (context) => const AdminGuard(child: AuditLogsScreen()),
      },
    );
  }
}

/// Decides initial screen: splash while loading, then home or login.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isInitialized) {
      // Splash screen while checking stored tokens
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield, size: 64, color: Ux4gColors.primary),
              const SizedBox(height: Ux4gSpacing.md),
              const Text(
                'RDSO Documents',
                style: TextStyle(
                  fontSize: Ux4gTypography.sizeH3,
                  fontWeight: Ux4gTypography.weightBold,
                  color: Ux4gColors.primary,
                ),
              ),
              const SizedBox(height: Ux4gSpacing.xl),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (auth.isLoggedIn) {
      return const HomeDashboard();
    }

    return const LoginScreen();
  }
}
