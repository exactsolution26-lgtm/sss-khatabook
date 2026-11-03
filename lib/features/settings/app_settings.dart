import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode theme = ThemeMode.light;
  AppLanguage language = AppLanguage.english;
  String? persistenceError;
  bool _disposed = false;
  int _revision = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || revision != _revision) return;
      theme = switch (prefs.getString('sss_theme_mode')) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      language = prefs.getString('sss_language') == 'hindi'
          ? AppLanguage.hindi
          : AppLanguage.english;
    } catch (_) {
      persistenceError =
          'Could not load preferences. Default settings are active.';
    }
    _notify();
  }

  Future<void> update({ThemeMode? themeMode, AppLanguage? appLanguage}) async {
    _revision++;
    theme = themeMode ?? theme;
    language = appLanguage ?? language;
    persistenceError = null;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = await prefs.setString('sss_theme_mode', theme.name);
      final savedLanguage = await prefs.setString(
        'sss_language',
        language.name,
      );
      if (!savedTheme || !savedLanguage)
        throw StateError('Preference write failed');
    } catch (_) {
      persistenceError =
          'Settings changed for this session but could not be saved.';
      _notify();
    }
  }

  String text(String key) => LocalizedStrings.get(key, language);
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
