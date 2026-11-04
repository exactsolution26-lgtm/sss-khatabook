import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_khata_app/core/localization/app_strings.dart';
import 'package:offline_khata_app/features/dashboard/dashboard_layout.dart';
import 'package:offline_khata_app/features/settings/app_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exactly six fixed layout identities reject arbitrary stored values', () {
    expect(DashboardLayout.values, hasLength(6));
    expect(
      DashboardLayout.values.map((layout) => layout.preferenceId).toSet(),
      hasLength(6),
    );
    for (final bad in [null, '', 'custom', 'dashboard_7', 2]) {
      expect(
        DashboardLayout.fromPreference(bad),
        DashboardLayout.dashboard1,
      );
    }
  });

  test('all six selections survive a settings restart', () async {
    for (final layout in DashboardLayout.values) {
      final settings = AppSettings();
      await settings.load();
      await settings.update(dashboardLayout: layout);
      settings.dispose();
      final restarted = AppSettings();
      await restarted.load();
      expect(restarted.dashboardLayout, layout);
      expect(restarted.language, AppLanguage.english);
      restarted.dispose();
    }
  });

  test('layout is independent of theme, language and unrelated stored data', () async {
    SharedPreferences.setMockInitialValues({
      'sss_theme_mode': 'dark',
      'sss_language': 'hindi',
      'business_marker': 'preserve',
    });
    final settings = AppSettings();
    await settings.load();
    await settings.update(dashboardLayout: DashboardLayout.dashboard5);
    expect(settings.theme, ThemeMode.dark);
    expect(settings.language, AppLanguage.hindi);
    await settings.update(themeMode: ThemeMode.light);
    await settings.update(appLanguage: AppLanguage.english);
    expect(settings.dashboardLayout, DashboardLayout.dashboard5);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('business_marker'), 'preserve');
    expect(prefs.getString('sss_dashboard_layout'), 'dashboard_5');
    settings.dispose();
  });

  test('rapid switches persist the latest selection across restarts', () async {
    final settings = AppSettings();
    await settings.load();
    await Future.wait([
      settings.update(dashboardLayout: DashboardLayout.dashboard2),
      settings.update(dashboardLayout: DashboardLayout.dashboard4),
      settings.update(dashboardLayout: DashboardLayout.dashboard6),
      settings.update(themeMode: ThemeMode.dark),
    ]);
    settings.dispose();
    final restarted = AppSettings();
    await restarted.load();
    expect(restarted.dashboardLayout, DashboardLayout.dashboard6);
    expect(restarted.theme, ThemeMode.dark);
    restarted.dispose();
  });

  test('a selection made during preference loading is retained', () async {
    SharedPreferences.setMockInitialValues({
      'sss_dashboard_layout': 'dashboard_2',
    });
    final settings = AppSettings();
    final loading = settings.load();
    final saving = settings.update(dashboardLayout: DashboardLayout.dashboard6);
    await Future.wait([loading, saving]);
    expect(settings.dashboardLayout, DashboardLayout.dashboard6);
    expect(settings.persistenceError, isNull);
    settings.dispose();
  });

  test('amount privacy survives restart without changing layout or language', () async {
    final settings = AppSettings();
    await settings.update(dashboardLayout: DashboardLayout.dashboard6,
      hideDashboardAmounts: true, appLanguage: AppLanguage.hindi);
    final restarted = AppSettings();
    await restarted.load();
    expect(restarted.hideDashboardAmounts, isTrue);
    expect(restarted.dashboardLayout, DashboardLayout.dashboard6);
    expect(restarted.language, AppLanguage.hindi);
    settings.dispose(); restarted.dispose();
  });

  test('preference failure is explicit and a later retry persists correctly', () async {
    var unavailable = true;
    final settings = AppSettings(preferences: () async {
      if (unavailable) throw StateError('Storage unavailable');
      return SharedPreferences.getInstance();
    });
    await settings.update(dashboardLayout: DashboardLayout.dashboard6);
    expect(settings.dashboardLayout, DashboardLayout.dashboard6);
    expect(settings.persistenceError, contains('could not be saved'));
    unavailable = false;
    await settings.update(dashboardLayout: DashboardLayout.dashboard6);
    final restarted = AppSettings(); await restarted.load();
    expect(settings.persistenceError, isNull);
    expect(restarted.dashboardLayout, DashboardLayout.dashboard6);
    settings.dispose(); restarted.dispose();
  });
}
