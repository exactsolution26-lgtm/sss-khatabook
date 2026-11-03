import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _themeKey = 'sss_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeKey);
    final storedLanguage = preferences.getString('sss_language');
    if (!mounted) return;
    setState(() {
      _language = storedLanguage == 'hindi' ? AppLanguage.hindi : AppLanguage.english;
      _themeMode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: LocalizedStrings.get('appTitle', _language),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: AppRoutes.openingBalance,
      routes: AppRoutes.routes,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
