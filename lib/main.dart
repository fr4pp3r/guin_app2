import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/config/theme.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/user_provider.dart';
import 'package:guin_app/providers/document_provider.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:guin_app/providers/barangay_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize();

    runApp(const MainApp());
  } catch (e) {
    // If initialization fails, show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => BarangayProvider()),
        ChangeNotifierProvider(create: (_) => IncidentReportProvider()),
      ],
      child: MaterialApp(
        title: 'Barangay E-Document System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
