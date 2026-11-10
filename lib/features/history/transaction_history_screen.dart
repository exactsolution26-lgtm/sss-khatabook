import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../core/utils/money.dart';
import '../settings/app_settings.dart';
import 'transaction_history.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key, required this.income});
  final bool income;
  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late bool income;
  late Future<HistoryPage> page;
  final pageStarts = <HistoryEntry?>[null];
  final search = TextEditingController();
  final scroll = ScrollController();
  int? accountId;
  String? category;
  DateTimeRange? range;
  bool get hindi => SettingsScope.of(context).language.name == 'hindi';
  String t(String en, String hi) => hindi ? hi : en;
  @override
  void initState() { super.initState(); income = widget.income; reload(); }
  void reload() {
    pageStarts.removeRange(1, pageStarts.length);
    loadPage();
  }
  void loadPage() {
    page = TransactionHistory.page(income, accountId: accountId, query: search.text,
      category: category, after: pageStarts.last,
      fromDate: range == null ? null : dates.DateUtils.formatDate(range!.start),
      toDate: range == null ? null : dates.DateUtils.formatDate(range!.end));
  }
  @override
  void dispose() { search.dispose(); scroll.dispose(); super.dispose(); }

  void changePage({HistoryEntry? after}) {
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() {
      if (after == null) { pageStarts.removeLast(); } else { pageStarts.add(after); }
      loadPage();
    });
  }

  Future<void> open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(reload);
  }

  Future<void> selectDates() async {
    final selected = await showDateRangePicker(context: context,
      firstDate: DateTime(2000), lastDate: dates.DateUtils.indiaToday(),
      initialDateRange: range);
    if (selected != null && mounted) setState(() { range = selected; reload(); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Transaction history', 'लेन-देन इतिहास'))),
    body: FutureBuilder<HistoryPage>(
      future: page,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: TextButton(
          onPressed: () => setState(loadPage),
          child: Text(t('Could not load entries — Retry', 'एंट्री नहीं खुलीं — फिर कोशिश करें'))));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final result = snapshot.data!;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final filtered = result.entries;
        final categories = {...result.categories, if (category != null) category!};
        final hasFilters = range != null || search.text.trim().isNotEmpty || category != null || accountId != null;
        return RefreshIndicator(
          onRefresh: () async { setState(reload); await page; },
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegmentedButton<bool>(segments: [
                  ButtonSegment(value: true, label: Text(t('Income', 'आय'))),
                  ButtonSegment(value: false, label: Text(t('Expenses', 'खर्च'))),
                ], selected: {income}, onSelectionChanged: (value) => setState(() {
                  income = value.single; category = null; reload();
                })),
                const SizedBox(height: 16),
                Card(color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(padding: const EdgeInsets.all(20), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(income ? t('Total income', 'कुल आय') : t('Total expenses', 'कुल खर्च')),
                      const SizedBox(height: 8),
                      Text(Money.format(result.totalPaise),
                        key: const ValueKey('history-total'),
                        style: Theme.of(context).textTheme.headlineMedium),
                      Text('${result.count} ${t('entries · current filters', 'एंट्री · चुने गए फ़िल्टर')}'),
                    ]))),
                const SizedBox(height: 16),
                TextField(controller: search, onChanged: (_) => setState(reload),
                  decoration: InputDecoration(labelText: t('Search name, mobile or note', 'नाम, मोबाइल या नोट खोजें'),
                    prefixIcon: const Icon(Icons.search))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(key: ValueKey('$income-$category'),
                  initialValue: category ?? '', isExpanded: true,
                  decoration: InputDecoration(labelText: t('Category', 'श्रेणी')),
                  items: [DropdownMenuItem(value: '', child: Text(t('All categories', 'सभी श्रेणियाँ'))),
                    for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (c) => setState(() { category = c == '' ? null : c; reload(); })),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(key: ValueKey('history-account-$accountId-${result.accounts.keys.join(',')}'),
                  initialValue: result.accounts.containsKey(accountId) ? accountId : 0, isExpanded: true,
                  decoration: InputDecoration(labelText: t('Account', 'खाता')),
                  items: [DropdownMenuItem(value: 0, child: Text(t('All accounts', 'सभी खाते'))),
                    for (final account in result.accounts.entries) DropdownMenuItem(value: account.key, child: Text(account.value))],
                  onChanged: (value) => setState(() { accountId = value == 0 ? null : value; reload(); })),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TextButton.icon(onPressed: selectDates, icon: const Icon(Icons.date_range),
                    label: Text(range == null ? t('All dates', 'सभी तारीखें')
                      : '${dates.DateUtils.formatDisplayDate(range!.start)} – ${dates.DateUtils.formatDisplayDate(range!.end)}')),
                  if (hasFilters)
                    TextButton(onPressed: () => setState(() { range = null; category = null; accountId = null; search.clear(); reload(); }),
                      child: Text(t('Clear filters', 'फ़िल्टर हटाएँ'))),
                ]),
                FilledButton.icon(onPressed: () async {
                  await Navigator.pushNamed(context, income ? '/income' : '/expenses');
                  if (mounted) setState(reload);
                }, icon: const Icon(Icons.add),
                  label: Text(income ? t('Add Income', 'आय जोड़ें') : t('Add Expense', 'खर्च जोड़ें'))),
                const SizedBox(height: 20),
                if (loading) const LinearProgressIndicator(),
                if (!loading && filtered.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(
                  hasFilters ? t('No entries match these filters.', 'इन फ़िल्टर से कोई एंट्री नहीं मिली।')
                    : t('No entries yet. Add your first entry.', 'अभी कोई एंट्री नहीं है। पहली एंट्री जोड़ें।'))),
              ]);
              if (index == filtered.length + 1) return Wrap(spacing: 12, children: [
                if (pageStarts.length > 1) OutlinedButton(onPressed: loading ? null : () => changePage(),
                  child: Text(t('Previous page', 'पिछला पेज'))),
                if (result.hasNext) OutlinedButton(onPressed: loading ? null : () => changePage(after: filtered.last),
                  child: Text(t('Next page', 'अगला पेज'))),
              ]);
              final entry = filtered[index - 1];
              final startsDay = index == 1 || filtered[index - 2].date != entry.date;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (startsDay) Padding(padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(HistoryEntry.accountingDate(entry.date),
                    style: Theme.of(context).textTheme.titleSmall)),
                Card(child: InkWell(key: ValueKey('history-${entry.reference}'),
                  onTap: loading ? null : () => open(TransactionDetailScreen(income: entry.income, id: entry.id, accountId: entry.accountId)),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(padding: const EdgeInsets.all(16), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.spaceBetween, children: [
                        Text(entry.name.isEmpty ? t('No contact linked', 'संपर्क नहीं जुड़ा') : entry.name,
                          style: Theme.of(context).textTheme.titleMedium),
                        Text('${income ? '+' : '−'}${Money.format(entry.paise)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: income ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error)),
                      ]),
                      if (entry.phone.isNotEmpty) Text(entry.phone),
                      Text('${entry.category} · ${entry.mode} · ${entry.account}'),
                      if (entry.note.isNotEmpty) Text(entry.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('${t('Saved', 'सेव किया')}: ${HistoryEntry.timestamp(entry.row['created_at'])}',
                        style: Theme.of(context).textTheme.bodySmall),
                      if (entry.attachmentCount > 0) Text('${entry.attachmentCount} ${t('attachment(s)', 'अटैचमेंट')}'),
                    ])))),
              ]);
            },
          ),
        );
      },
    ),
  );
}
