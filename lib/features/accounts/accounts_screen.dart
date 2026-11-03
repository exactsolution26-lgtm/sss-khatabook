import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../settings/app_settings.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late Future<List<AccountModel>> _accounts;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _accounts = AccountTable.getAllAccounts();

  Future<void> _edit([AccountModel? account]) async {
    final name = TextEditingController(text: account?.name ?? '');
    final balance = TextEditingController(
      text: account?.openingBalance.toStringAsFixed(2) ?? '0.00',
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? 'New Account' : 'Edit Account'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Account name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Opening balance (₹)',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n < 0
                        ? 'Enter a non-negative amount'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(context, (
                  name.text.trim(),
                  double.parse(balance.text),
                ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dispose after the dialog route has finished its closing transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    balance.dispose();
    if (result == null || !mounted) return;
    try {
      await AccountTable.saveAccount(
        name: result.$1,
        openingBalance: result.$2,
        id: account?.id,
      );
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save account')));
    }
  }

  Future<void> _remove(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete empty account?'),
        content: const Text(
          'Accounts with financial transactions cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AccountTable.deleteEmptyAccount(account.id!);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account could not be deleted. It may have financial records.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(SettingsScope.of(context).text('accounts'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.add),
      label: const Text('New Account'),
    ),
    body: FutureBuilder<List<AccountModel>>(
      future: _accounts,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(_reload),
              child: const Text('Could not load accounts — Retry'),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(
            child: Text('Add your first customer or business account.'),
          );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: snapshot.data!
              .map(
                (a) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(a.name),
                    subtitle: Text(
                      'Opening: ₹${a.openingBalance.toStringAsFixed(2)}',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AccountLedgerScreen(account: a),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          value == 'edit' ? _edit(a) : _remove(a),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete empty account'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class AccountLedgerScreen extends StatefulWidget {
  const AccountLedgerScreen({super.key, required this.account});
  final AccountModel account;
  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  late Future<List<Map<String, Object?>>> _entries;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<Map<String, Object?>>> _load() async {
    final db = await DBHelper.database;
    return db.rawQuery(
      '''SELECT id, amount, date, description AS note, 'income' AS kind FROM income WHERE account_id = ?
      UNION ALL SELECT id, amount, date, note, 'expense' AS kind FROM expenses WHERE account_id = ?
      ORDER BY date ASC, kind ASC, id ASC''',
      [widget.account.id, widget.account.id],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.account.name)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search ledger',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _entries = _load()),
                    child: const Text('Could not load ledger — Retry'),
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var running = widget.account.openingBalance;
              final tiles = <Widget>[
                ListTile(
                  title: const Text('Opening balance'),
                  trailing: Text('₹${running.toStringAsFixed(2)}'),
                ),
              ];
              for (final entry in snapshot.data!) {
                final amount = (entry['amount'] as num).toDouble();
                final income = entry['kind'] == 'income';
                running += income ? amount : -amount;
                if (!'${entry['note']} ${entry['date']} ${entry['kind']} $amount'
                    .toLowerCase()
                    .contains(_query))
                  continue;
                tiles.add(
                  ListTile(
                    title: Text(
                      '${income ? '+' : '−'} ₹${amount.toStringAsFixed(2)}',
                    ),
                    subtitle: Text('${entry['date']} • ${entry['note'] ?? ''}'),
                    trailing: Text('₹${running.toStringAsFixed(2)}'),
                  ),
                );
              }
              return ListView(children: tiles);
            },
          ),
        ),
      ],
    ),
  );
}
