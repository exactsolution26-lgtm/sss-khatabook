import 'package:flutter/material.dart';
import 'core/security/backend_mode.dart';

import 'app.dart';
import 'core/startup_error.dart';
import 'core/error_reporting.dart';
import 'database/platform/database_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureErrorReporting(() { startApplication(); });
  configureDatabase();
  await startApplication();
}

Future<void> startApplication() async {
  try {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (!BackendMode.localOnly(url,key)) {
      runApp(const MaterialApp(home: Scaffold(body: SafeArea(child: Center(child: Padding(
        padding: EdgeInsets.all(24), child: Text('Cloud account access is not ready. Tenant authentication, storage and synchronization must be configured and verified before cloud access can open.\nSupport code: SSS-CLOUD-SETUP',textAlign:TextAlign.center)))))));
      return;
    }
    runApp(const MyApp());
  } catch (_) {
    // Do not expose backend URLs, tokens, stack traces or financial data.
    debugPrint('SSS_STARTUP_INITIALIZATION_FAILED');
    runApp(StartupErrorApp(onRetry: startApplication));
  }
}
