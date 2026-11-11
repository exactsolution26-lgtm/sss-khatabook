import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../models/account_model.dart';
import '../accounts/accounts_screen.dart';
import '../analysis/analysis_logic.dart';
import '../history/transaction_detail_screen.dart';
import '../history/transaction_history.dart';
import '../settings/app_settings.dart';
import 'dashboard_layout.dart';
import 'super_admin_preview.dart';

extension DashboardTemplateName on DashboardLayout {
  String title(bool hindi) => (hindi
      ? const ['क्लासिक', 'बैलेंस फ़ोकस', 'कॉम्पैक्ट', 'ओवरव्यू', 'खाते', 'टाइमलाइन']
      : const ['Classic', 'Balance Focus', 'Compact', 'Overview', 'Accounts', 'Timeline'])[index];
}

/// Each layout reads the same snapshot. Local filters affect presentation only.
class DashboardTemplateView extends StatefulWidget {
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

  @override
  State<DashboardTemplateView> createState() => _DashboardTemplateViewState();
}

class _DashboardTemplateViewState extends State<DashboardTemplateView> {
  static final _currency = NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 2,
  );

  int monthOffset = 0;
  String? kind;
  String query = '';
  bool showSearch = false;

  String t(String en, String hi) => widget.hindi ? hi : en;
  String money(num value) => widget.hideAmounts ? '••••' : _currency.format(value);
  Map<String, dynamic> get data => widget.data;
  void open(String route) => widget.onNavigate(route);

  Color get accent => const [
    Color(0xff087653), Color(0xff59268c), Color(0xff1648ad),
    Color(0xff673bb2), Color(0xff176047), Color(0xff823650),
  ][widget.layout.index];

  TextStyle? get heading => Theme.of(context).textTheme.titleLarge?.copyWith(
    fontWeight: FontWeight.w700,
  );

  Widget amount(int index, {Color? color, bool hero = false}) {
    final field = const ['totalBalance', 'totalIncome', 'totalExpense'][index];
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        money(data[field] as num),
        key: ValueKey('metric-$index'),
        style: (hero ? Theme.of(context).textTheme.headlineLarge : heading)
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget balance(IconData icon, {bool compact = false}) {
    final index = widget.layout.index;
    final bright = index == 0 || index == 5;
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final foreground = bright && !darkMode ? const Color(0xff251c2b) : Colors.white;
    final colors = bright && !darkMode
        ? [Color.lerp(Colors.white, accent, .09)!, Color.lerp(Colors.white, accent, .19)!]
        : [Color.lerp(accent, Colors.black, .52)!, accent];
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Total Balance', 'कुल बैलेंस'), style: TextStyle(color: foreground)),
          const SizedBox(height: 6),
          amount(0, color: foreground, hero: !compact),
        ])),
        const SizedBox(width: 12),
        ExcludeSemantics(child: _DepthIcon(icon: icon, color: accent, size: compact ? 47 : 70)),
      ]),
    );
  }

  Widget totals({bool includeBalance = false}) {
    return LayoutBuilder(builder: (context, box) {
      final first = includeBalance ? 0 : 1;
      final count = 3 - first;
      final stacked = box.maxWidth < 270 || MediaQuery.textScalerOf(context).scale(14) > 23;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = first; i < 3; i++)
          SizedBox(
            width: stacked ? box.maxWidth : (box.maxWidth - (count - 1) * 8) / count,
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('dashboard-total-$i'),
                onTap: i == 0 ? null : () => open(i == 1 ? '/income-history' : '/expense-history'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text([t('Balance', 'बैलेंस'), t('Income', 'आय'), t('Expenses', 'खर्च')][i]),
                    const SizedBox(height: 4),
                    amount(i, color: i == 2 ? scheme.error : null),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  Widget entryButtons() => Wrap(spacing: 8, runSpacing: 8, children: [
    FilledButton.icon(
      key: const ValueKey('dashboard-add-income'),
      style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
      onPressed: () => open('/income'),
      icon: const Icon(Icons.add),
      label: Text(t('Add Income', 'आय जोड़ें')),
    ),
    OutlinedButton.icon(
      key: const ValueKey('dashboard-add-expense'),
      onPressed: () => open('/expenses'),
      icon: const Icon(Icons.add),
      label: Text(t('Add Expense', 'खर्च जोड़ें')),
    ),
  ]);

  Widget shortcuts() => Wrap(spacing: 8, runSpacing: 8, children: [
    for (final item in [
      (t('Accounts', 'खाते'), Icons.account_balance_outlined, '/accounts'),
      (t('Reports', 'रिपोर्ट'), Icons.bar_chart_outlined, '/reports'),
      (t('Opening Balance', 'शुरुआती बैलेंस'), Icons.account_balance_wallet_outlined, '/opening-balance'),
      (t('WhatsApp Drafts', 'WhatsApp ड्राफ्ट'), Icons.chat_outlined, '/whatsapp/share'),
    ]) ActionChip(
      avatar: Icon(item.$2, size: 18),
      label: Text(item.$1),
      onPressed: () => open(item.$3),
    ),
  ]);

  Widget accounts() {
    final rows = (data['accountDetails'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((row) => !(row['account'] as AccountModel).isArchived).toList();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = [const Color(0xffdceba9), const Color(0xff176047), const Color(0xfff0d5ad)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t('Accounts', 'खाते'), style: heading),
      const SizedBox(height: 8),
      if (rows.isEmpty) Text(t('No accounts yet.', 'अभी कोई खाता नहीं है।')),
      for (final (index, row) in rows.take(5).indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  colors[index % 3],
                  Color.lerp(colors[index % 3], Colors.black, .13)!,
                ]),
              ),
              child: ListTile(
                key: ValueKey('dashboard-account-${(row['account'] as AccountModel).id}'),
                textColor: index % 3 == 1 ? Colors.white : const Color(0xff15231a),
                iconColor: index % 3 == 1 ? Colors.white : const Color(0xff15231a),
                leading: Icon([Icons.account_balance_wallet, Icons.account_balance, Icons.payments][index % 3]),
                title: Text((row['account'] as AccountModel).name),
                subtitle: Text(money(row['balance'] as num)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final callback = widget.onOpenAccount;
                  if (callback == null) {
                    open('/accounts');
                  } else {
                    callback(row['account'] as AccountModel);
                  }
                },
              ),
            ),
          ),
        ),
      TextButton(
        onPressed: () => open('/accounts'),
        child: Text(t('View all accounts (${rows.length})', 'सभी खाते देखें (${rows.length})'),
          style: TextStyle(color: dark ? null : accent)),
      ),
    ]);
  }

  Widget compactToolbar() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(
        onPressed: () => setState(() { showSearch = !showSearch; query = ''; }),
        icon: const Icon(Icons.search),
        label: Text(t('Search', 'खोजें')),
      ),
      PopupMenuButton<String>(
        tooltip: t('Filter recent entries', 'हाल की एंट्री फ़िल्टर करें'),
        onSelected: (value) => setState(() => kind = value.isEmpty ? null : value),
        itemBuilder: (_) => [
          PopupMenuItem(value: '', child: Text(t('All entries', 'सभी एंट्री'))),
          PopupMenuItem(value: 'income', child: Text(t('Income', 'आय'))),
          PopupMenuItem(value: 'expense', child: Text(t('Expenses', 'खर्च'))),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(switch (kind) {
            'income' => t('Filter: Income', 'फ़िल्टर: आय'),
            'expense' => t('Filter: Expenses', 'फ़िल्टर: खर्च'),
            _ => t('Filter', 'फ़िल्टर'),
          }),
        ),
      ),
    ]),
    if (showSearch) TextField(
      autofocus: true,
      decoration: InputDecoration(labelText: t('Search recent entries', 'हाल की एंट्री खोजें')),
      onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
    ),
  ]);

  Widget recent({bool grouped = false, int limit = 4}) {
    final rows = (data['recentTransactions'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    final compact = widget.layout == DashboardLayout.dashboard3;
    final accountsOnly = widget.layout == DashboardLayout.dashboard5;
    final filtered = rows.where((row) {
      if (accountsOnly && row['account_id'] == null) return false;
      if (!compact) return true;
      if (kind != null && row['kind'] != kind) return false;
      return ['contact_name', 'contact_phone', 'category', 'account_name',
        if (!widget.hideAmounts) 'note'].any(
        (key) => (row[key]?.toString() ?? '').toLowerCase().contains(query),
      );
    }).take(limit).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        accountsOnly ? t('Recent account activity', 'हाल की खाता गतिविधि')
            : grouped && !compact ? t('Timeline', 'टाइमलाइन') : t('Recent Entries', 'हाल की एंट्री'),
        style: heading,
      ),
      const SizedBox(height: 8),
      if (filtered.isEmpty) Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t('No recent entries to show.', 'दिखाने के लिए कोई हाल की एंट्री नहीं है।')),
      ),
      for (final (index, row) in filtered.indexed) ...[
        if (grouped && (index == 0 || filtered[index - 1]['date'] != row['date']))
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(HistoryEntry.accountingDate(row['date'] as String),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        entry(row, rail: grouped && !compact),
      ],
      Wrap(spacing: 8, children: [
        TextButton(onPressed: () => open('/income-history'), child: Text(t('All income', 'सभी आय'))),
        TextButton(onPressed: () => open('/expense-history'), child: Text(t('All expenses', 'सभी खर्च'))),
      ]),
    ]);
  }

  Widget entry(Map<String, Object?> row, {required bool rail}) {
    final income = row['kind'] == 'income';
    final route = income ? '/income-history' : '/expense-history';
    final note = widget.hideAmounts ? null : row['note']?.toString();
    final title = [
      row['contact_name']?.toString(),
      note,
      row['category']?.toString(),
      income ? t('Income', 'आय') : t('Expense', 'खर्च'),
    ].whereType<String>().firstWhere((value) => value.trim().isNotEmpty);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: rail ? scheme.surfaceContainerLow : Colors.transparent,
        shape: rail ? RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ) : null,
        child: InkWell(
          key: ValueKey('recent-${row['kind']}-${row['id']}'),
          onTap: () {
            final callback = widget.onOpenEntry;
            final id = row['id'];
            if (callback != null && id is int) {
              callback(income, id, row['account_id'] as int?);
            } else {
              open(route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DepthIcon(icon: income ? Icons.south_west : Icons.north_east,
                size: 31, color: income ? const Color(0xff13745b) : const Color(0xffac3e50)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 12, runSpacing: 2, alignment: WrapAlignment.spaceBetween, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${widget.hideAmounts ? '' : income ? '+' : '−'}${money((row['amount'] as num).abs())}',
                    style: TextStyle(color: income ? scheme.primary : scheme.error, fontWeight: FontWeight.w700)),
                ]),
                if (!rail) Text(HistoryEntry.accountingDate(row['date'] as String),
                  style: Theme.of(context).textTheme.bodySmall),
                if (rail) Text('${t('Saved', 'सेव हुआ')}: ${HistoryEntry.timestamp(row['created_at'])}',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
              const Icon(Icons.chevron_right, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  Widget analytics() {
    final now = dates.DateUtils.indiaToday();
    final month = DateTime(now.year, now.month + monthOffset);
    final monthKey = DateFormat('yyyy-MM').format(month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (days / 7).ceil();
    final income = List<int>.filled(weeks, 0);
    final expense = List<int>.filled(weeks, 0);
    final categories = <String, int>{};
    final rows = (data['dashboardAnalytics'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    for (final row in rows.where((row) => row['month'] == monthKey)) {
      final week = row['week'] as int;
      if (week >= weeks) continue;
      final paise = (row['paise'] as num).round();
      if (row['kind'] == 'income') {
        income[week] += paise;
      } else {
        expense[week] += paise;
        final category = row['category'] as String;
        categories.update(category, (value) => value + paise, ifAbsent: () => paise);
      }
    }
    final maximum = [1, ...income, ...expense].reduce((a, b) => a > b ? a : b);
    final ranked = categories.entries.toList()
      ..sort((a, b) {
        final result = b.value.compareTo(a.value);
        return result == 0 ? a.key.compareTo(b.key) : result;
      });
    const teal = Color(0xff13836f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(t('Cash Flow', 'नकदी प्रवाह'), style: heading),
          DropdownButton<int>(
            key: const ValueKey('cash-flow-period'),
            value: monthOffset,
            onChanged: (value) {
              if (value != null) setState(() => monthOffset = value);
            },
            items: [
              DropdownMenuItem(value: 0, child: Text(t('This month', 'इस महीने'))),
              DropdownMenuItem(value: -1, child: Text(t('Last month', 'पिछले महीने'))),
            ],
          ),
        ],
      ),
      if (widget.hideAmounts)
        Text(t('Amounts hidden', 'राशियां छिपी हैं'))
      else ...[
        Text(DateFormat.yMMMM().format(month)),
        Wrap(spacing: 14, children: [
          TextButton.icon(onPressed: () => open('/income-history'),
            icon: Icon(Icons.circle, color: accent, size: 12),
            label: Text(t('Income', 'आय'))),
          TextButton.icon(onPressed: () => open('/expense-history'),
            icon: const Icon(Icons.circle, color: teal, size: 12),
            label: Text(t('Expenses', 'खर्च'))),
        ]),
        if (income.every((value) => value == 0) && expense.every((value) => value == 0))
          Text(t('No entries in this period.', 'इस अवधि में कोई एंट्री नहीं है।'))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < weeks; i++)
              Expanded(
                child: Tooltip(
                  message: '${t('Income', 'आय')} ${money(income[i] / 100)} · '
                      '${t('Expenses', 'खर्च')} ${money(expense[i] / 100)}',
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end, children: [
                      chartBar(income[i] / maximum, accent),
                      const SizedBox(width: 3),
                      chartBar(expense[i] / maximum, teal),
                    ]),
                    const SizedBox(height: 6),
                    Text('${i * 7 + 1}–${math.min(days, (i + 1) * 7)}',
                      textAlign: TextAlign.center),
                  ]),
                ),
              ),
          ]),
        const SizedBox(height: 18),
        Text(t('Spending Categories', 'खर्च की श्रेणियाँ'), style: heading),
        if (ranked.isEmpty)
          Text(t('No expenses in this period.', 'इस अवधि में कोई खर्च नहीं है।')),
        for (final item in ranked.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
                Text(item.key.isEmpty ? t('Uncategorized', 'बिना श्रेणी') : item.key),
                Text(money(item.value / 100)),
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (item.value / math.max(1, ranked.first.value)).clamp(0.0, 1.0).toDouble(),
                color: accent,
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
          ),
        if (ranked.length > 5)
          TextButton(onPressed: () => open('/expense-history'),
            child: Text(t('All expenses', 'सभी खर्च'))),
      ],
    ]);
  }

  Widget chartBar(double fraction, Color color) => Flexible(
    child: Container(
      width: 14,
      height: math.max(0.0, fraction * 112).toDouble(),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        gradient: LinearGradient(colors: [
          Color.lerp(color, Colors.white, .35)!, color,
          Color.lerp(color, Colors.black, .20)!,
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contents = switch (widget.layout) {
      DashboardLayout.dashboard1 => [
        balance(Icons.menu_book_rounded), totals(), recent(), entryButtons(),
      ],
      DashboardLayout.dashboard2 => [
        balance(Icons.account_balance_wallet_rounded), entryButtons(), totals(), recent(limit: 2),
      ],
      DashboardLayout.dashboard3 => [
        balance(Icons.toll_rounded, compact: true), totals(), entryButtons(),
        compactToolbar(), recent(grouped: true, limit: 12),
      ],
      DashboardLayout.dashboard4 => [
        analytics(), totals(includeBalance: true), entryButtons(),
      ],
      DashboardLayout.dashboard5 => [
        balance(Icons.account_balance_wallet_rounded), accounts(), totals(), recent(), entryButtons(),
      ],
      DashboardLayout.dashboard6 => [
        balance(Icons.calendar_month_rounded, compact: true), totals(),
        recent(grouped: true, limit: 12), entryButtons(),
      ],
    };
    return Column(
      key: ValueKey(widget.layout.preferenceId),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in contents) ...[child, const SizedBox(height: 14)],
        shortcuts(),
        if ((data['unassignedExpenseCount'] as num? ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(t(
              'Totals include historic expenses without an account.',
              'कुल राशि में बिना खाते वाले पुराने खर्च भी शामिल हैं।',
            )),
          ),
      ],
    );
  }
}

class _DepthIcon extends StatelessWidget {
  const _DepthIcon({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .24),
      border: Border.all(color: Colors.white38),
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .32)!, color, Color.lerp(color, Colors.black, .35)!],
      ),
      boxShadow: [BoxShadow(color: color.withValues(alpha: .38),
        offset: Offset(0, size * .09), blurRadius: size * .14)],
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, size: size * .56, color: Colors.white,
        shadows: [Shadow(color: Colors.black54, offset: Offset(0, size * .045), blurRadius: 3)]),
    ),
  );
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
    data = AnalysisLogic().getAnalysisData(includeDashboardAnalytics: true);
  }

  Future<void> open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(() { data = AnalysisLogic().getAnalysisData(includeDashboardAnalytics: true); });
  }

  Future<void> openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() { data = AnalysisLogic().getAnalysisData(includeDashboardAnalytics: true); });
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
          retry: () => setState(() { data = AnalysisLogic().getAnalysisData(includeDashboardAnalytics: true); }),
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
