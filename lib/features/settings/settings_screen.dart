import '../../core/localization/app_text.dart';
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
                label: AppText('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: AppText('Dark'),
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
              ButtonSegment(value: AppLanguage.english, label: AppText('English')),
              ButtonSegment(value: AppLanguage.hindi, label: Text('हिंदी')),
            ],
            selected: {settings.language},
            onSelectionChanged: (selection) =>
                settings.update(appLanguage: selection.first),
          ),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.event_note), title: const AppText('Follow-ups & Reminders'),
            trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/followups')),
          ListTile(leading: const Icon(Icons.payments_outlined), title: const AppText('Dues & Partial Payments'),
            trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/dues')),
          ListTile(leading: const Icon(Icons.lock_outline), title: const AppText('PIN & Biometrics'),
            trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/security')),
          ListTile(leading: const Icon(Icons.backup_outlined), title: const AppText('Backup & Restore'),
            trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/backup')),
          ListTile(leading: const Icon(Icons.history), title: const AppText('Audit History'),
            trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, '/audit')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: Text(settings.language == AppLanguage.hindi
                ? 'डैशबोर्ड चुनें' : 'Choose Dashboard'),
            subtitle: Text(settings.language == AppLanguage.hindi
                ? 'छह डिज़ाइन · प्रीव्यू देखें और लागू करें'
                : 'Six designs · preview and apply'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/dashboard-previews'),
          ),
          for(final item in <(String,String,IconData,String)>[
            ('Getting Started','शुरुआत करें',Icons.checklist,'/getting-started'),
            ('Business Profile','व्यवसाय प्रोफ़ाइल',Icons.business_outlined,'/profile'),
            ('Contact Directory','संपर्क सूची',Icons.contacts_outlined,'/contacts'),
            ('Message Templates','संदेश टेम्पलेट',Icons.message_outlined,'/message-templates'),
            ('WhatsApp Draft History','WhatsApp ड्राफ्ट इतिहास',Icons.open_in_new,'/draft-history'),
            ('Detailed Reports','विस्तृत रिपोर्ट',Icons.analytics_outlined,'/reports/detailed'),
            ('Import CSV','CSV आयात करें',Icons.upload_file_outlined,'/import'),
            ('Help & Support','सहायता',Icons.help_outline,'/support'),
          ]) ListTile(leading:Icon(item.$3),title:Text(settings.language==AppLanguage.hindi?item.$2:item.$1),
            trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.pushNamed(context,item.$4)),
          if (settings.persistenceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(settings.persistenceError!),
            ),
          const SizedBox(height: 32),
          const Text('SSS Khatabook • Development build'),
          const SizedBox(height: 8),
          const AppText('Keep a secure backup of your records. Cloud sync and subscription enforcement require additional setup and verification.',
          ),
        ],
      ),
    );
  }
}
