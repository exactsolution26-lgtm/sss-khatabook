import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import 'app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(settings.text('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: Text(settings.language == AppLanguage.hindi
                ? 'छह डैशबोर्ड प्रीव्यू' : 'Six Dashboard Previews'),
            subtitle: Text(settings.language == AppLanguage.hindi
                ? 'पुनर्निर्मित डिज़ाइन · स्वीकृति बाकी है'
                : 'Reconstructed designs · awaiting approval'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/dashboard-previews'),
          ),
          const SizedBox(height: 24),
          Text(
            settings.language == AppLanguage.hindi ? 'थीम' : 'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {
              settings.theme == ThemeMode.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
            },
            onSelectionChanged: (selection) =>
                settings.update(themeMode: selection.first),
          ),
          const SizedBox(height: 32),
          Text(
            settings.text('language'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.english, label: Text('English')),
              ButtonSegment(value: AppLanguage.hindi, label: Text('हिंदी')),
            ],
            selected: {settings.language},
            onSelectionChanged: (selection) =>
                settings.update(appLanguage: selection.first),
          ),
          if (settings.persistenceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(settings.persistenceError!),
            ),
          const SizedBox(height: 32),
          const Text('SSS Khatabook • Development build'),
          const SizedBox(height: 8),
          const Text(
            'Keep a secure backup of your records. Cloud sync and subscription enforcement require additional setup and verification.',
          ),
        ],
      ),
    );
  }
}
