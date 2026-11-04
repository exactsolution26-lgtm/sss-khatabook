import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/app_settings.dart';
import 'features/backup/automatic_backup.dart';
import 'features/security/security_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final settings = AppSettings();
  @override
  void initState() {
    super.initState();
    settings.load();
    AutomaticBackup.instance.start();
  }

  @override
  void dispose() {
    AutomaticBackup.instance.stop();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    settings: settings,
    child: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: settings.text('appTitle'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.theme,
        initialRoute: AppRoutes.dashboard,
        routes: AppRoutes.routes,
        builder: (context, child) => AppLockGate(child: child!),
      ),
    ),
  );
}
