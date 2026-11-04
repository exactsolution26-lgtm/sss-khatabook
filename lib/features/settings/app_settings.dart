import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';
import '../dashboard/dashboard_layout.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode theme = ThemeMode.light;
  AppLanguage language = AppLanguage.english;
  DashboardLayout dashboardLayout = DashboardLayout.dashboard1;
  String? persistenceError;
  bool _disposed = false;
  int _revision = 0;
  Future<void> _pendingSave = Future<void>.value();

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
      dashboardLayout = DashboardLayout.fromPreference(
        prefs.get('sss_dashboard_layout'),
      );
    } catch (_) {
      persistenceError =
          'Could not load preferences. Default settings are active.';
    }
    _notify();
  }

  Future<void> update({
    ThemeMode? themeMode,
    AppLanguage? appLanguage,
    DashboardLayout? dashboardLayout,
  }) {
    _revision++;
    final revision = _revision;
    theme = themeMode ?? theme;
    language = appLanguage ?? language;
    this.dashboardLayout = dashboardLayout ?? this.dashboardLayout;
    final nextTheme = theme.name;
    final nextLanguage = language.name;
    final nextLayout = this.dashboardLayout.preferenceId;
    persistenceError = null;
    _notify();
    // Serial writes prevent a slower earlier selection overwriting the latest.
    _pendingSave = _pendingSave.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedTheme = await prefs.setString('sss_theme_mode', nextTheme);
        final savedLanguage = await prefs.setString('sss_language', nextLanguage);
        final savedLayout = await prefs.setString(
          'sss_dashboard_layout',
          nextLayout,
        );
        if (!savedTheme || !savedLanguage || !savedLayout) {
          throw StateError('Preference write failed');
        }
      } catch (_) {
        if (revision == _revision) {
          persistenceError =
              'Settings changed for this session but could not be saved.';
          _notify();
        }
      }
    });
    return _pendingSave;
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
