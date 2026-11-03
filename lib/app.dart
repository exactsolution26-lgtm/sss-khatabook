import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _themeKey = 'sss_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeKey);
    if (!mounted) return;
    setState(() {
      _themeMode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSS Khatabook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: AppRoutes.openingBalance,
      routes: AppRoutes.routes,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              elevation: 2,
              borderRadius: BorderRadius.circular(24),
              child: PopupMenuButton<ThemeMode>(
                tooltip: 'Choose app theme',
                icon: const Icon(Icons.palette_outlined),
                onSelected: _setTheme,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
                  PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
                  PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
