import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../settings/app_settings.dart';
import 'archived_accounts_screen.dart';
import '../whatsapp/verified_share_screen.dart';
import '../whatsapp/whatsapp_share_service.dart';
import '../reports/ledger_export_screen.dart';
import '../entries/attachment_widgets.dart';
import '../entries/record_editor.dart';
import '../entries/record_recovery.dart';
import '../../core/utils/date_utils.dart' as dates;

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

  void _reload() { _accounts = AccountTable.getAllAccounts(); }

  Future<void> _edit([AccountModel? account]) async {
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (_) => _AccountEditorDialog(account: account),
    );
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
        ).showSnackBar(const SnackBar(content: AppText('Could not save account')));
    }
  }

  Future<void> _remove(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete empty account?'),
        content: const AppText('Accounts with financial transactions cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete'),
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
            content: AppText('Account could not be deleted. It may have financial records.',
            ),
          ),
        );
    }
  }

  Future<void> _archive(AccountModel account) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const AppText('Archive account?'),
      content:const AppText('Records and balances stay in reports and history. Restore the account before adding or editing its financial entries.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const AppText('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const AppText('Archive'))]));
    if(ok!=true)return;
    try{await AccountTable.archive(account.id!,archived:true);if(mounted)setState(_reload);}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('Could not archive account.')));}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(SettingsScope.of(context).text('accounts')),actions:[IconButton(tooltip:'Archived accounts',icon:const Icon(Icons.archive_outlined),
      onPressed:()async{await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const ArchivedAccountsScreen()));if(mounted)setState(_reload);})]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.add),
      label: const AppText('New Account'),
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
            child: AppText('Add your first customer or business account.'),
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
                          value == 'edit' ? _edit(a) : value=='archive'?_archive(a):_remove(a),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: AppText('Edit')),
                        PopupMenuItem(value:'archive',child:AppText('Archive account')),
                        PopupMenuItem(
                          value: 'delete',
                          child: AppText('Delete empty account'),
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

class _AccountEditorDialog extends StatefulWidget {
  const _AccountEditorDialog({this.account});
  final AccountModel? account;
  @override
  State<_AccountEditorDialog> createState() => _AccountEditorDialogState();
}

class _AccountEditorDialogState extends State<_AccountEditorDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.account?.name ?? '');
  late final balance = TextEditingController(
    text: widget.account?.openingBalance.toStringAsFixed(2) ?? '0.00',
  );
  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? 'New Account' : 'Edit Account'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 120,
              decoration: const InputDecoration(label: AppText('Account name')),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                label: AppText('Opening balance (₹)'),
                helperText: 'Locked after the first transaction.',
              ),
              validator: (value) {
                final n = double.tryParse(value ?? '');
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
        child: const AppText('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, (
              name.text.trim(),
              balance.text == widget.account?.openingBalance.toStringAsFixed(2)
                  ? widget.account!.openingBalance
                  : double.parse(balance.text),
            ));
        },
        child: const AppText('Save'),
      ),
    ],
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
      '''SELECT id, amount, date, description AS note, created_at, contact_name, contact_phone, 'income' AS kind FROM income WHERE account_id = ?
      UNION ALL SELECT id, amount, date, note, created_at, contact_name, contact_phone, 'expense' AS kind FROM expenses WHERE account_id = ?
      ORDER BY date ASC, created_at ASC, kind ASC, id ASC''',
      [widget.account.id, widget.account.id],
    );
  }

  Future<void> _change(Map<String,Object?> entry, bool remove) async {
    final income = entry['kind'] == 'income';
    if (!remove) {
      await Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => RecordEditor(income: income,id: entry['id'] as int,accountId: widget.account.id!)));
      if(mounted) setState(() {_entries=_load();});
      return;
    }
    final reason = await showDialog<String>(context: context,builder: (_) => const _DeleteReasonDialog());
    if(reason==null) return;
    try {await RecordRecovery.remove(income: income,id: entry['id'] as int,accountId: widget.account.id!,reason: reason);
      if(mounted) {setState(() {_entries=_load();});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('Deleted. You can restore it from Deleted Entries.')));}}
    catch(_) {if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('Could not delete. Allocated payments must be reversed in Payment History.')));}
  }

  void _share(WhatsAppMessageType type, {int? incomeId, String month = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VerifiedShareScreen(
          draft: WhatsAppDraft(
            type: type,
            customer: widget.account.name,
            amount: 0,
            timestampUtc: DateTime.now().toUtc(),
            sourceAccountId: widget.account.id,
            sourceIncomeId: incomeId,
            month: month,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.account.name),
      actions: [
        IconButton(tooltip: 'Deleted Entries',icon: const Icon(Icons.restore_from_trash_outlined),onPressed: () async {
          await Navigator.push(context,MaterialPageRoute<void>(builder: (_) => RecycleBinScreen(accountId: widget.account.id)));
          if(mounted) setState(() {_entries=_load();});
        }),
        IconButton(tooltip: 'Ledger PDF & CSV', icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => LedgerExportScreen(accountId: widget.account.id!)))),
        IconButton(
          tooltip: 'Share ledger',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _share(WhatsAppMessageType.ledger),
        ),
        IconButton(
          tooltip: 'Share monthly statement',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (selected != null && mounted)
              _share(
                WhatsAppMessageType.monthlyStatement,
                month:
                    '${selected.year}-${selected.month.toString().padLeft(2, '0')}',
              );
          },
        ),
      ],
    ),
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
                    onPressed: () => setState(() {_entries = _load();}),
                    child: const Text('Could not load ledger — Retry'),
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var running = widget.account.openingBalance;
              final tiles = <Widget>[
                ListTile(
                  title: const AppText('Opening balance'),
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
                    subtitle: Text('${entry['date']} • ${entry['note'] ?? ''}'
                      '${entry['contact_name'] == null ? '' : '\n${entry['contact_name']} · ${entry['contact_phone']}'}'
                      '${entry['created_at'] == null ? '' : '\nSaved: ${dates.DateUtils.formatIstDateTime(DateTime.parse(entry['created_at'] as String))}'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${running.toStringAsFixed(2)}'),
                        PopupMenuButton<String>(tooltip: 'Entry actions',
                          onSelected: (value) {
                            if(value == 'edit' || value == 'delete') {_change(entry,value == 'delete');}
                            else if (value == 'receipt') {
                              _share(WhatsAppMessageType.receipt, incomeId: entry['id'] as int);
                            } else {
                              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AttachmentScreen(
                                entryId: entry['id'] as int, income: income)));
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit',child: AppText('Edit entry')),
                            const PopupMenuItem(value: 'delete',child: AppText('Delete entry')),
                            const PopupMenuItem(value: 'attachments', child: AppText('View Attachments')),
                            if (income) const PopupMenuItem(value: 'receipt', child: AppText('Share recorded receipt')),
                          ]),
                      ],
                    ),
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

class _DeleteReasonDialog extends StatefulWidget {
  const _DeleteReasonDialog();
  @override State<_DeleteReasonDialog> createState() => _DeleteReasonDialogState();
}
class _DeleteReasonDialogState extends State<_DeleteReasonDialog> {
  final reason=TextEditingController();
  @override void dispose() {reason.dispose();super.dispose();}
  @override Widget build(BuildContext context) => AlertDialog(title: const AppText('Delete this entry?'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,children: [
      const AppText('The balance will be recalculated. This entry and its attachments remain recoverable in Deleted Entries.'),
      TextField(controller: reason,maxLength: 500,decoration: const InputDecoration(labelText: 'Reason (required)')),
    ])),actions: [TextButton(onPressed: () => Navigator.pop(context),child: const AppText('Cancel')),
      FilledButton(onPressed: () {if(reason.text.trim().isNotEmpty) Navigator.pop(context,reason.text.trim());},child: const AppText('Delete'))]);
}
