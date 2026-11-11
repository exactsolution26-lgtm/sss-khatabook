import 'package:flutter/material.dart';

import '../accounts/accounts_screen.dart';
import '../analysis/analysis_logic.dart';
import '../history/transaction_detail_screen.dart';
import '../settings/app_settings.dart';
import 'dashboard_templates.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.loadSummary});
  final Future<Map<String, dynamic>> Function()? loadSummary;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _summary;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = widget.loadSummary?.call() ??
        AnalysisLogic().getAnalysisData(includeDashboardAnalytics: true);
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(_reload);
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final hindi = settings.language.name == 'hindi';
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.text('appTitle')),
        actions: [
          IconButton(
            tooltip: settings.text('accounts'),
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => _open('/accounts'),
          ),
          IconButton(
            tooltip: settings.hideDashboardAmounts
                ? (hindi ? 'राशि दिखाएं' : 'Show amounts') : (hindi ? 'राशि छिपाएं' : 'Hide amounts'),
            icon: Icon(settings.hideDashboardAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => settings.update(hideDashboardAmounts: !settings.hideDashboardAmounts),
          ),
          IconButton(tooltip: settings.text('settings'), icon: const Icon(Icons.tune),
            onPressed: () => _open('/settings')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _open('/income-history');
          if (index == 2) _open('/reports');
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: hindi ? 'होम' : 'Home'),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: hindi ? 'लेजर' : 'Ledger'),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), label: settings.text('reports')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          try { await _summary; } catch (_) { /* The snapshot shows an actionable retry. */ }
        },
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20), children: [
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(settings.text('dashboard'), style: Theme.of(context).textTheme.titleSmall),
              Text(hindi ? 'सक्रिय: ${settings.dashboardLayout.title(true)}'
                  : 'Active: ${settings.dashboardLayout.title(false)}', key: const ValueKey('active-dashboard')),
              OutlinedButton.icon(onPressed: () => _open('/dashboard-previews'),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: Text(hindi ? 'डैशबोर्ड बदलें' : 'Change dashboard')),
            ]),
            Text(hindi ? 'सभी तारीखें · इस डिवाइस के रिकॉर्ड' : 'All time · records on this device'),
            if (settings.persistenceError != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(hindi ? 'सेटिंग इस सत्र में लागू है, लेकिन सेव नहीं हुई। फिर कोशिश करें।' : settings.persistenceError!)),
            const SizedBox(height: 20),
            DashboardSnapshot(future: _summary, hindi: hindi, retry: () => setState(_reload),
              builder: (data) => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                if((data['accounts'] as List).isEmpty) OutlinedButton.icon(icon:const Icon(Icons.checklist),
                  onPressed:()=>_open('/getting-started'),label:Text(hindi?'शुरुआत करें':'Getting Started')),
                DashboardTemplateView(
                layout: settings.dashboardLayout, data: data, hindi: hindi,
                hideAmounts: settings.hideDashboardAmounts, onNavigate: _open,
                onOpenAccount: (account) => _openPage(AccountLedgerScreen(account: account)),
                onOpenEntry: (income, id, accountId) => _openPage(TransactionDetailScreen(
                    income: income, id: id, accountId: accountId))),
              ])),
            const SizedBox(height: 24),
            Text(hindi ? 'और सुविधाएं' : 'More tools', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(hindi ? 'कार्य टाइमर' : 'Work Timer'), onPressed: () => _open('/work')),
              ActionChip(avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text(hindi ? 'बकाया और आंशिक भुगतान' : 'Dues & Partial Payments'), onPressed: () => _open('/dues')),
              ActionChip(avatar: const Icon(Icons.event_note, size: 18),
                label: Text(hindi ? 'फ़ॉलो-अप और रिमाइंडर' : 'Follow-ups & Reminders'), onPressed: () => _open('/followups')),
              ActionChip(avatar: const Icon(Icons.settings_outlined, size: 18),
                label: Text(settings.text('settings')), onPressed: () => _open('/settings')),
            ]),
          ]),
        )),
      ),
    );
  }
}
