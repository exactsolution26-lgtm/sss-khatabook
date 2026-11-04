import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../models/account_model.dart';
import '../accounts/accounts_screen.dart';
import '../analysis/analysis_logic.dart';
import '../history/transaction_detail_screen.dart';
import '../history/transaction_history.dart';
import '../settings/app_settings.dart';
import 'dashboard_layout.dart';
import 'super_admin_preview.dart';

/// Reconstructed layouts. These names are not recovered design approvals.
extension DashboardTemplateName on DashboardLayout {
  String title(bool hindi) => (hindi
      ? const ['क्लासिक', 'बैलेंस फ़ोकस', 'कॉम्पैक्ट', 'ओवरव्यू', 'खाते', 'टाइमलाइन']
      : const ['Classic', 'Balance Focus', 'Compact', 'Overview', 'Accounts', 'Timeline'])[index];
}

/// All six presentations consume the same read-only financial snapshot.
class DashboardTemplateView extends StatelessWidget {
  const DashboardTemplateView({
    super.key,
    required this.layout,
    required this.data,
    required this.onNavigate,
    this.onOpenAccount,
    this.onOpenEntry,
    this.hindi = false,
    this.hideAmounts = false,
  });

  final DashboardLayout layout;
  final Map<String, dynamic> data;
  final ValueChanged<String> onNavigate;
  final ValueChanged<AccountModel>? onOpenAccount;
  final void Function(bool income, int id, int? accountId)? onOpenEntry;
  final bool hindi;
  final bool hideAmounts;

  String t(String en, String hi) => hindi ? hi : en;
  String money(dynamic value) => hideAmounts ? '••••' : NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 2,
  ).format(value as num);

  List<(String, dynamic)> get metrics => [
    (t('Total Balance', 'कुल बैलेंस'), data['totalBalance']),
    (t('Income', 'आय'), data['totalIncome']),
    (t('Expenses', 'खर्च'), data['totalExpense']),
  ];

  List<(String, IconData, String)> get actions => [
    (t('Add Income', 'आय जोड़ें'), Icons.south_west, '/income'),
    (t('Add Expense', 'खर्च जोड़ें'), Icons.north_east, '/expenses'),
    (t('Accounts', 'खाते'), Icons.people_outline, '/accounts'),
    (t('Reports', 'रिपोर्ट'), Icons.bar_chart, '/reports'),
    (t('Opening Balance', 'शुरुआती बैलेंस'), Icons.account_balance_wallet_outlined, '/opening-balance'),
    (t('WhatsApp Drafts', 'WhatsApp ड्राफ्ट'), Icons.chat_outlined, '/whatsapp/share'),
  ];

  Widget metric(BuildContext context, int index, {bool emphasis = false}) {
    final item = metrics[index];
    return Card(
      clipBehavior: Clip.antiAlias,
      color: emphasis ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: index == 0 ? null : () => onNavigate(index == 1 ? '/income-history' : '/expense-history'),
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
      ),
    );
  }

  Widget metricGrid(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final wide = box.maxWidth >= 650;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < metrics.length; i++)
        SizedBox(width: wide ? (box.maxWidth - 16) / 3
            : i == 0 || largeText ? box.maxWidth : (box.maxWidth - 8) / 2,
          child: metric(context, i, emphasis: i == 0)),
    ]);
  });

  Widget actionGrid(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final columns = box.maxWidth >= 650 ? 3
        : MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 2;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final action in actions)
        SizedBox(width: (box.maxWidth - (columns - 1) * 8) / columns,
          child: Card(clipBehavior: Clip.antiAlias, child: InkWell(
            onTap: () => onNavigate(action.$3),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('Accounts', 'खाते'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (accounts.isEmpty) Text(t('No accounts yet.', 'अभी कोई खाता नहीं है।')),
      for (final row in accounts.take(5))
        Card(child: ListTile(
          key: ValueKey('dashboard-account-${(row['account'] as AccountModel).id}'),
          title: Text((row['account'] as AccountModel).name),
          subtitle: Text('${t('Balance', 'बैलेंस')}: ${money(row['balance'])}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpenAccount != null
              ? onOpenAccount!(row['account'] as AccountModel) : onNavigate('/accounts'),
        )),
      TextButton(onPressed: () => onNavigate('/accounts'),
        child: Text(t('View all accounts (${accounts.length})', 'सभी खाते देखें (${accounts.length})'))),
    ]);
  }

  Widget timeline(BuildContext context, {int limit = 4}) {
    final entries = data['recentTransactions'] as List? ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('Recent entries', 'हाल की एंट्री'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(t('Newest transaction dates first', 'नई लेन-देन तारीख पहले')),
      if (entries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(t('No transactions yet. Add your first income or expense.',
          'अभी कोई लेन-देन नहीं है। पहली आय या खर्च जोड़ें।'))),
      for (final row in entries.take(limit))
        Card(clipBehavior: Clip.antiAlias, child: InkWell(
          key: ValueKey('recent-${row['kind']}-${row['id']}'),
          onTap: () => onOpenEntry != null && row['id'] is int
              ? onOpenEntry!(row['kind'] == 'income', row['id'] as int, row['account_id'] as int?)
              : onNavigate(row['kind'] == 'income' ? '/income-history' : '/expense-history'),
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['kind'] == 'income' ? metrics[1].$1 : metrics[2].$1} · ${money(row['amount'])}',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if ((row['contact_name'] ?? '').toString().isNotEmpty)
                Text(row['contact_name'].toString()),
              if ((row['contact_phone'] ?? '').toString().isNotEmpty)
                Text(row['contact_phone'].toString()),
              Text(row['account_name']?.toString() ?? t('Unassigned legacy account', 'पुराना असंबद्ध खाता')),
              Text('${t('Date', 'तारीख')}: ${HistoryEntry.accountingDate(row['date'] as String)}'),
              Text('${t('Saved', 'सेव हुआ')}: ${HistoryEntry.timestamp(row['created_at'])}'),
              if (!hideAmounts && (row['note'] ?? '').toString().isNotEmpty)
                Text(row['note'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(t('View entry →', 'एंट्री देखें →'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ])),
        )),
      Wrap(spacing: 8, children: [
        TextButton(onPressed: () => onNavigate('/income-history'), child: Text(t('All income', 'सभी आय'))),
        TextButton(onPressed: () => onNavigate('/expense-history'), child: Text(t('All expenses', 'सभी खर्च'))),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 20);
    final contents = switch (layout) {
      DashboardLayout.dashboard1 => [metricGrid(context), gap, actionGrid(context), gap, timeline(context)],
      DashboardLayout.dashboard2 => [
        metric(context, 0, emphasis: true), gap,
        for (var i = 1; i < 3; i++) metric(context, i), gap,
        actionChips(), gap, accountList(context),
      ],
      DashboardLayout.dashboard3 => [
        Card(child: Column(children: [for (var i = 0; i < 3; i++)
          ListTile(onTap: i == 0 ? null : () => onNavigate(i == 1 ? '/income-history' : '/expense-history'),
            title: Text(metrics[i].$1), subtitle: Text(money(metrics[i].$2), key: ValueKey('metric-$i'))),
        ])), gap, actionChips(),
      ],
      DashboardLayout.dashboard4 => [
        metricGrid(context), gap,
        Text(t('Income and expenses', 'आय और खर्च'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (hideAmounts) Text(t('Amounts hidden', 'राशियां छिपी हैं'))
        else for (var i = 1; i < 3; i++) ...[
          Text(metrics[i].$1),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              semanticsLabel: metrics[i].$1,
              minHeight: 10,
              value: (metrics[i].$2 as num).abs() /
                math.max(1, math.max((metrics[1].$2 as num).abs(), (metrics[2].$2 as num).abs())),
            )),
        ], gap, actionChips(), gap, timeline(context),
      ],
      DashboardLayout.dashboard5 => [accountList(context), gap, metricGrid(context), gap, actionChips()],
      DashboardLayout.dashboard6 => [actionChips(), gap, metricGrid(context), gap, timeline(context, limit: 12)],
    };
    return Column(key: ValueKey(layout.preferenceId),
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...contents,
        if ((data['unassignedExpenseCount'] as num? ?? 0) > 0) Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(t('Totals include expenses without an assigned historic account. View All expenses for details.',
            'कुल राशि में बिना खाते वाले पुराने खर्च भी शामिल हैं। जानकारी के लिए सभी खर्च देखें।'))),
      ]);
  }
}

/// Preview is transient. Only Use this dashboard changes the active preference.
class DashboardPreviewsScreen extends StatefulWidget {
  const DashboardPreviewsScreen({super.key});
  @override
  State<DashboardPreviewsScreen> createState() => _DashboardPreviewsScreenState();
}

class _DashboardPreviewsScreenState extends State<DashboardPreviewsScreen> {
  late Future<Map<String, dynamic>> data;
  DashboardLayout? selected;
  bool applying = false;

  @override
  void initState() {
    super.initState();
    data = AnalysisLogic().getAnalysisData();
  }

  Future<void> open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(() { data = AnalysisLogic().getAnalysisData(); });
  }

  Future<void> openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() { data = AnalysisLogic().getAnalysisData(); });
  }

  Future<void> apply(AppSettings settings, DashboardLayout layout) async {
    setState(() => applying = true);
    await settings.update(dashboardLayout: layout);
    if (!mounted) return;
    setState(() => applying = false);
    if (settings.persistenceError != null) return;
    final hindi = settings.language == AppLanguage.hindi;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hindi
        ? '${layout.title(true)} डैशबोर्ड सेव हुआ' : '${layout.title(false)} dashboard saved')));
    Navigator.pop(context);
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
            onPressed: applying ? null : () => settings.update(themeMode:
              settings.theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark)),
          IconButton(tooltip: hindi ? 'भाषा बदलें' : 'Switch language',
            icon: const Icon(Icons.translate),
            onPressed: applying ? null : () => settings.update(appLanguage:
              hindi ? AppLanguage.english : AppLanguage.hindi)),
        ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16),
        child: FilledButton.icon(key: const ValueKey('apply-dashboard'),
          onPressed: applying ? null : () => apply(settings, layout),
          icon: Icon(applying ? Icons.hourglass_top : Icons.check),
          label: Text(applying ? (hindi ? 'सेव हो रहा है…' : 'Saving…')
              : (hindi ? 'यह डैशबोर्ड इस्तेमाल करें' : 'Use this dashboard'))))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(hindi ? 'पुनर्निर्मित डिज़ाइन · मूल छह डिज़ाइन नहीं मिले'
          : 'Reconstructed designs · original six visuals not recovered',
          style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(hindi ? 'अपने लोकल रिकॉर्ड का लाइव प्रीव्यू। बदलने के लिए नीचे का बटन दबाएं।'
          : 'Live preview of your local records. Apply below to change your dashboard.'),
        const SizedBox(height: 12),
        Text(hindi ? 'सक्रिय: ${settings.dashboardLayout.title(true)}'
          : 'Active: ${settings.dashboardLayout.title(false)}'),
        const SizedBox(height: 12),
        DropdownButtonFormField<DashboardLayout>(
          key: const ValueKey('dashboard-selector'), initialValue: layout,
          isExpanded: true,
          decoration: InputDecoration(labelText: hindi ? 'टेम्पलेट' : 'Template'),
          items: [for (final item in DashboardLayout.values)
            DropdownMenuItem(value: item, child: Text(item.title(hindi)))],
          onChanged: applying ? null : (value) { if (value != null) setState(() => selected = value); },
        ),
        if (settings.persistenceError != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(hindi ? 'इस सत्र में लागू है, लेकिन सेटिंग सेव नहीं हुई। फिर कोशिश करें।'
            : settings.persistenceError!)),
        const SizedBox(height: 20),
        Text(layout.title(hindi), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        DashboardSnapshot(future: data, hindi: hindi,
          retry: () => setState(() { data = AnalysisLogic().getAnalysisData(); }),
          builder: (snapshot) => DashboardTemplateView(layout: layout, data: snapshot,
            hindi: hindi, hideAmounts: settings.hideDashboardAmounts, onNavigate: open,
            onOpenAccount: (account) => openPage(AccountLedgerScreen(account: account)),
            onOpenEntry: (income, id, accountId) => openPage(TransactionDetailScreen(
              income: income, id: id, accountId: accountId)))),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () => openPage(const SuperAdminPreview()),
          child: Text(hindi ? 'सुपर एडमिन · सिमुलेटेड प्रीव्यू' : 'Super Admin · simulated preview')),
      ]),
    );
  }
}

class DashboardSnapshot extends StatelessWidget {
  const DashboardSnapshot({super.key, required this.future, required this.hindi,
    required this.retry, required this.builder});
  final Future<Map<String, dynamic>> future;
  final bool hindi;
  final VoidCallback retry;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future, builder: (context, snapshot) {
      // Do not show stale values while a refresh or navigation reload is pending.
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || !snapshot.hasData) return Card(child: Padding(
        padding: const EdgeInsets.all(20), child: Column(children: [
          Text(hindi ? 'लोकल रिकॉर्ड नहीं खुले। आपका डेटा हटाया नहीं गया है।'
            : 'Could not open local records. Your data has not been deleted.'),
          TextButton(onPressed: retry, child: Text(hindi ? 'फिर कोशिश करें' : 'Retry')),
        ])));
      return builder(snapshot.data!);
    });
}
