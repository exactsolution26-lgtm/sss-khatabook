import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/app_settings.dart';
import 'features/backup/automatic_backup.dart';
import 'features/security/security_screen.dart';
import 'core/security/app_lock.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.appLock, this.automaticBackups = true});
  final AppLock? appLock;
  final bool automaticBackups;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final settings = AppSettings();
  @override
  void initState() {
    super.initState();
    settings.load();
    if (widget.automaticBackups) AutomaticBackup.instance.start();
  }

  @override
  void dispose() {
    if (widget.automaticBackups) AutomaticBackup.instance.stop();
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
        locale: Locale(settings.language.name=='hindi'?'hi':'en'),
        supportedLocales: const [Locale('en'),Locale('hi')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.theme,
        initialRoute: AppRoutes.dashboard,
        routes: AppRoutes.routes,
        builder: (context, child) => AppLockGate(controller: widget.appLock, child: child!),
      ),
    ),
  );
}
