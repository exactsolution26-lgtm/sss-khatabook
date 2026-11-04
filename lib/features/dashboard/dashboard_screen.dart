import 'package:flutter/material.dart';

import '../analysis/analysis_logic.dart';
import '../settings/app_settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
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

  void _reload() { _summary = AnalysisLogic().getAnalysisData(); }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final hindi = settings.language.name == 'hindi';
    final actions = <(String, IconData, String)>[
      (settings.text('accounts'), Icons.people_outline, '/accounts'),
      (settings.text('income'), Icons.south_west_rounded, '/income-history'),
      (settings.text('expenses'), Icons.north_east_rounded, '/expense-history'),
      (settings.text('reports'), Icons.bar_chart_rounded, '/reports'),
      (
        hindi ? 'शुरुआती बैलेंस' : 'Opening Balance',
        Icons.account_balance_wallet_outlined,
        '/opening-balance',
      ),
      (hindi ? 'कार्य टाइमर' : 'Work Timer', Icons.timer_outlined, '/work'),
      (
        hindi ? 'WhatsApp ड्राफ्ट' : 'WhatsApp Drafts',
        Icons.chat_outlined,
        '/whatsapp/share',
      ),
      (settings.text('settings'), Icons.tune_rounded, '/settings'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.text('appTitle')),
        actions: [
          IconButton(
            tooltip: settings.text('settings'),
            icon: const Icon(Icons.tune),
            onPressed: () => _open('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await _summary;
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              settings.text('dashboard'),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              hindi
                  ? 'आपके कारोबार का हिसाब, एक जगह।'
                  : 'Your business, clearly accounted for.',
            ),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Could not open local records. Your data has not been deleted.',
                          ),
                          TextButton(
                            onPressed: () => setState(_reload),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 700
                        ? (constraints.maxWidth - 32) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _metric(
                          hindi ? 'कुल बैलेंस' : 'Total Balance',
                          data['totalBalance'],
                          width,
                          true,
                        ),
                        _metric(
                          settings.text('income'),
                          data['totalIncome'],
                          width,
                          false,
                          route: '/income-history',
                        ),
                        _metric(
                          settings.text('expenses'),
                          data['totalExpense'],
                          width,
                          false,
                          route: '/expense-history',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 580
                    ? 3
                    : 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: actions
                      .map(
                        (action) => SizedBox(
                          width:
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _open(action.$3),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      action.$2,
                                      size: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      action.$1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, dynamic value, double width, bool primary, {String? route}) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        color: primary ? scheme.primaryContainer : null,
        child: InkWell(
          onTap: route == null ? null : () => _open(route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 12),
              Text(
                '₹${(value as num).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
