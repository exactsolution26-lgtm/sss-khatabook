import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/startup_error.dart';
import 'core/error_reporting.dart';
import 'database/platform/database_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureErrorReporting(() => runApp(const MyApp()));
  configureDatabase();
  await startApplication();
}

Future<void> startApplication() async {
  try {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty != key.isEmpty) {
      throw StateError('Backend configuration incomplete');
    }
    if (url.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: key);
    }
    runApp(const MyApp());
  } catch (_) {
    // Do not expose backend URLs, tokens, stack traces or financial data.
    debugPrint('SSS_STARTUP_INITIALIZATION_FAILED');
    runApp(StartupErrorApp(onRetry: startApplication));
  }
}
