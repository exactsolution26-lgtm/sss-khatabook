import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analysis/analysis_logic.dart';
import '../settings/app_settings.dart';
import '../../core/localization/app_strings.dart';
import 'dashboard_layout.dart';
import 'super_admin_preview.dart';

/// Newly reconstructed layouts. These names are not recovered approvals.
extension DashboardTemplateName on DashboardLayout {
  String title(bool hindi) => (hindi
      ? const ['क्लासिक', 'बैलेंस फ़ोकस', 'कॉम्पैक्ट', 'ओवरव्यू', 'खाते', 'टाइमलाइन']
      : const ['Classic', 'Balance Focus', 'Compact', 'Overview', 'Accounts', 'Timeline'])[index];
}

class DashboardTemplateView extends StatelessWidget {
  const DashboardTemplateView({
    super.key,
    required this.layout,
    required this.data,
    required this.onNavigate,
    this.hindi = false,
  });

  final DashboardLayout layout;
  final Map<String, dynamic> data;
  final ValueChanged<String> onNavigate;
  final bool hindi;

  String money(dynamic value) => NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 2,
  ).format(value as num);

  List<(String, dynamic)> get metrics => [
    (hindi ? 'कुल बैलेंस' : 'Total Balance', data['totalBalance']),
    (hindi ? 'आय' : 'Income', data['totalIncome']),
    (hindi ? 'खर्च' : 'Expenses', data['totalExpense']),
  ];

  List<(String, IconData, String)> get actions => [
    (hindi ? 'आय जोड़ें' : 'Add Income', Icons.south_west, '/income'),
    (hindi ? 'खर्च जोड़ें' : 'Add Expense', Icons.north_east, '/expenses'),
    (hindi ? 'खाते' : 'Accounts', Icons.people_outline, '/accounts'),
    (hindi ? 'रिपोर्ट' : 'Reports', Icons.bar_chart, '/reports'),
    (hindi ? 'शुरुआती बैलेंस' : 'Opening Balance', Icons.account_balance_wallet_outlined, '/opening-balance'),
    (hindi ? 'WhatsApp ड्राफ्ट' : 'WhatsApp Drafts', Icons.chat_outlined, '/whatsapp/share'),
  ];

  Widget metric(BuildContext context, int index, {bool emphasis = false}) {
    final item = metrics[index];
    return Card(
      color: emphasis ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.$1),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(money(item.$2), key: ValueKey('metric-$index'),
              style: emphasis ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.titleLarge)),
        ]),
      ),
    );
  }

  Widget metricGrid(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final wide = box.maxWidth >= 650;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < metrics.length; i++)
        SizedBox(width: wide ? (box.maxWidth - 16) / 3
            : i == 0 ? box.maxWidth : (box.maxWidth - 8) / 2,
          child: metric(context, i, emphasis: i == 0)),
    ]);
  });

  Widget actionGrid() => LayoutBuilder(builder: (context, box) {
    final columns = box.maxWidth >= 650 ? 3 : 2;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final action in actions)
        SizedBox(width: (box.maxWidth - (columns - 1) * 8) / columns,
          child: Card(child: InkWell(
            onTap: () => onNavigate(action.$3),
            borderRadius: BorderRadius.circular(12),
            child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(action.$2), const SizedBox(height: 12), Text(action.$1),
              ])),
          ))),
    ]);
  });

  Widget actionChips() => Wrap(spacing: 8, runSpacing: 8, children: [
    for (final action in actions)
      ActionChip(avatar: Icon(action.$2, size: 18), label: Text(action.$1),
        onPressed: () => onNavigate(action.$3)),
  ]);

  Widget accountList(BuildContext context) {
    final accounts = data['accountDetails'] as List;
    if (accounts.isEmpty) return Text(hindi ? 'अभी कोई खाता नहीं है।' : 'No accounts yet.');
    return Column(children: [
      for (final row in accounts)
        Card(child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(row['account'].name as String),
          subtitle: Text('${hindi ? 'बैलेंस' : 'Balance'}: ${money(row['balance'])}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onNavigate('/accounts'),
        )),
    ]);
  }

  Widget timeline() {
    final entries = data['recentTransactions'] as List? ?? const [];
    if (entries.isEmpty) return Text(hindi ? 'अभी कोई लेन-देन नहीं है।' : 'No transactions yet.');
    return Column(children: [
      for (final row in entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(row['kind'] == 'income' ? Icons.south_west : Icons.north_east),
          title: Text('${row['kind'] == 'income' ? metrics[1].$1 : metrics[2].$1} · ${money(row['amount'])}'),
          subtitle: Text('${row['note'] ?? ''}\n${row['date']}'),
          isThreeLine: true,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: 20);
    final contents = switch (layout) {
      DashboardLayout.dashboard1 => [metricGrid(context), gap, actionGrid()],
      DashboardLayout.dashboard2 => [
        metric(context, 0, emphasis: true), gap,
        ...[for (var i = 1; i < 3; i++) metric(context, i)], gap,
        actionChips(), gap, accountList(context),
      ],
      DashboardLayout.dashboard3 => [
        Card(child: Column(children: [for (var i = 0; i < 3; i++)
          ListTile(title: Text(metrics[i].$1), subtitle: Text(money(metrics[i].$2),
            key: ValueKey('metric-$i'))),
        ])), gap, actionChips(),
      ],
      DashboardLayout.dashboard4 => [
        metricGrid(context), gap,
        Text(hindi ? 'आय और खर्च' : 'Income and expenses',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var i = 1; i < 3; i++) ...[
          Text(metrics[i].$1),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (metrics[i].$2 as num).abs() /
                math.max(1, math.max((metrics[1].$2 as num).abs(), (metrics[2].$2 as num).abs())),
            )),
        ], gap, actionChips(),
      ],
      DashboardLayout.dashboard5 => [
        accountList(context), gap, metricGrid(context), gap, actionChips(),
      ],
      DashboardLayout.dashboard6 => [
        actionChips(), gap, timeline(), gap, metricGrid(context),
      ],
    };
    return Column(key: ValueKey(layout.preferenceId),
      crossAxisAlignment: CrossAxisAlignment.stretch, children: contents);
  }
}

/// Opt-in preview; it does not replace the approved production dashboard.
class DashboardPreviewsScreen extends StatefulWidget {
  const DashboardPreviewsScreen({super.key});
  @override
  State<DashboardPreviewsScreen> createState() => _DashboardPreviewsScreenState();
}

class _DashboardPreviewsScreenState extends State<DashboardPreviewsScreen> {
  late Future<Map<String, dynamic>> data;
  DashboardLayout? selected;

  @override
  void initState() {
    super.initState();
    data = AnalysisLogic().getAnalysisData();
  }

  Future<void> open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(() {data = AnalysisLogic().getAnalysisData();});
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final hindi = settings.language == AppLanguage.hindi;
    final layout = selected ?? settings.dashboardLayout;
    return Scaffold(
      appBar: AppBar(title: Text(hindi ? 'डैशबोर्ड प्रीव्यू' : 'Dashboard Previews'),
        actions: [
          IconButton(tooltip: hindi ? 'थीम बदलें' : 'Switch theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => settings.update(themeMode:
              settings.theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark)),
          IconButton(tooltip: hindi ? 'भाषा बदलें' : 'Switch language',
            icon: const Icon(Icons.translate),
            onPressed: () => settings.update(appLanguage:
              hindi ? AppLanguage.english : AppLanguage.hindi)),
        ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        OutlinedButton(onPressed: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const SuperAdminPreview())),
          child: Text(hindi ? 'सुपर एडमिन डिज़ाइन प्रीव्यू' : 'Super Admin design preview')),
        const SizedBox(height: 12),
        Text(hindi ? 'पुनर्निर्मित डिज़ाइन · आपकी स्वीकृति बाकी है'
          : 'Reconstruction previews · awaiting your design approval',
          style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        DropdownButtonFormField<DashboardLayout>(
          key: ValueKey(layout), initialValue: layout,
          isExpanded: true,
          decoration: InputDecoration(labelText: hindi ? 'टेम्पलेट' : 'Template'),
          items: [for (final item in DashboardLayout.values)
            DropdownMenuItem(value: item, child: Text(item.title(hindi)))],
          onChanged: (value) {
            if (value == null) return;
            setState(() => selected = value);
            settings.update(dashboardLayout: value);
          },
        ),
        const SizedBox(height: 20),
        Text(layout.title(hindi), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
          if (snapshot.hasError) return Column(children: [
            Text(hindi ? 'रिकॉर्ड नहीं खुले।' : 'Could not open local records.'),
            TextButton(onPressed: () => setState(() {data = AnalysisLogic().getAnalysisData();}),
              child: Text(hindi ? 'फिर कोशिश करें' : 'Retry')),
          ]);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return DashboardTemplateView(layout: layout, data: snapshot.data!,
            hindi: hindi, onNavigate: open);
        }),
      ]),
    );
  }
}
