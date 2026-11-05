import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../core/utils/money.dart';
import '../entries/contact_fields.dart';
import '../entries/party_snapshot.dart';
import '../whatsapp/verified_share_screen.dart';
import '../whatsapp/whatsapp_share_service.dart';
import '../followups/followup_screen.dart';
import 'dues_service.dart';

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key, this.accountId}); final int? accountId;
  @override
  State<DuesScreen> createState() => _DuesScreenState();
}
class _DuesScreenState extends State<DuesScreen> {
  final service = DuesService();
  late Future<(List<AccountModel>, List<Map<String, Object?>>)> data;
  bool showSettled = false;
  @override
  void initState() {super.initState(); data = load();}
  Future<(List<AccountModel>, List<Map<String, Object?>>)> load() async =>
    (await AccountTable.getAllAccounts(), await service.list(accountId: widget.accountId));
  void refresh() {if (mounted) setState(() {data = load();});}
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const AppText('Dues & Partial Payments'), actions: [
    IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh)),
  ]), body: FutureBuilder(future: data, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Could not load dues — Retry')));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final (accounts, rows) = snapshot.data!;
    var receive = 0, pay = 0;
    for (final row in rows) {if (row['kind'] == 'receivable') {receive += row['remaining_paise'] as int;} else {pay += row['remaining_paise'] as int;}}
    return ListView(padding: const EdgeInsets.all(20), children: [
      const AppText('Track amounts still to receive or pay. Creating a due does not change cash/bank balance; recording its payment does.'),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        Chip(label: Text('To receive: ${Money.format(receive)}')),
        Chip(label: Text('To pay: ${Money.format(pay)}')),
      ]),
      FilledButton.icon(onPressed: accounts.isEmpty ? null : () async {
        await showDialog<int>(context: context, builder: (_) => _CreateDue(accounts: accounts, accountId: widget.accountId)); refresh();
      }, icon: const Icon(Icons.add), label: const AppText('Add amount due')),
      if (accounts.isEmpty) TextButton(onPressed: () async {await Navigator.pushNamed(context, '/accounts'); refresh();}, child: const AppText('Create a customer/account first')),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const AppText('Show settled dues'), value: showSettled,
        onChanged: (value) => setState(() => showSettled = value)),
      for (final row in rows.where((r) => showSettled || (r['remaining_paise'] as int) > 0)) Card(child: Padding(
        padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row['account_name'] as String, style: Theme.of(context).textTheme.titleLarge),
          Text('${row['kind'] == 'receivable' ? 'To receive' : 'To pay'} · ${row['description']}'),
          if (row['contact_name'] != null) Text('${row['contact_name']} · ${row['contact_phone']}'),
          if (row['due_date'] != null) Text('Due date: ${row['due_date']}'),
          const SizedBox(height: 8), Text('Total: ${Money.format(row['total_paise'] as int)} · Paid: ${Money.format(row['paid_paise'] as int)}'),
          Text('Remaining: ${Money.format(row['remaining_paise'] as int)}', style: Theme.of(context).textTheme.titleMedium),
          Text('Saved at: ${dates.DateUtils.formatIstDateTime(DateTime.parse(row['created_at'] as String))}'),
          Wrap(spacing: 12, children: [
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FollowupScreen(
              accountId: row['account_id'] as int, obligationId: row['id'] as int))), child: const AppText('Add follow-up')),
            if ((row['remaining_paise'] as int) > 0) TextButton(onPressed: () async {
              await showDialog<int>(context: context, builder: (_) => _RecordPayment(due: row)); refresh();
            }, child: Text(row['kind'] == 'receivable' ? 'Record received payment' : 'Record paid amount')),
            TextButton(onPressed: () async {
              await showDialog<void>(context: context, builder: (_) => _PaymentHistory(obligationId: row['id'] as int)); refresh();
            }, child: const AppText('Payment history')),
          ]),
        ]))),
      if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: AppText('No amounts due yet.')),
    ]);
  }));
}

class _CreateDue extends StatefulWidget {
  const _CreateDue({required this.accounts, this.accountId}); final List<AccountModel> accounts; final int? accountId;
  @override
  State<_CreateDue> createState() => _CreateDueState();
}
class _CreateDueState extends State<_CreateDue> {
  final amount = TextEditingController(), description = TextEditingController(), name = TextEditingController(), phone = TextEditingController();
  final form = GlobalKey<FormState>(); late int account;
  bool receivable = true, busy = false; DateTime? dueDate; String? error;
  @override
  void initState() {super.initState(); account = widget.accountId ?? widget.accounts.first.id!;}
  @override
  void dispose() {amount.dispose(); description.dispose(); name.dispose(); phone.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) => AlertDialog(title: const AppText('Add amount due'), content: SizedBox(width: 450,
    child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<int>(initialValue: account, isExpanded: true, decoration: const InputDecoration(labelText: 'Customer / Account'),
        items: [for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))], onChanged: (v) {if (v != null) account = v;}),
      DropdownButtonFormField<bool>(initialValue: receivable, decoration: const InputDecoration(labelText: 'Direction'),
        items: const [DropdownMenuItem(value: true, child: AppText('To receive')), DropdownMenuItem(value: false, child: AppText('To pay'))], onChanged: (v) {if (v != null) receivable = v;}),
      TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Total amount (INR)'), validator: (v) {try {Money.parse(v ?? ''); return null;} catch (_) {return 'Enter a positive amount with at most two decimals';}}),
      TextFormField(controller: description, maxLength: 2000, decoration: const InputDecoration(label: AppText('Description')),
        validator: (v) => v == null || v.trim().isEmpty ? 'Description required' : null),
      ContactFields(name: name, phone: phone),
      TextButton.icon(icon: const Icon(Icons.calendar_month), label: Text(dueDate == null ? 'Choose due date (optional)' : dates.DateUtils.formatDisplayDate(dueDate!)),
        onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: dueDate ?? dates.DateUtils.indiaToday(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (mounted && picked != null) setState(() => dueDate = picked);
        }),
      if (error != null) Text(error!),
    ])))), actions: [
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const AppText('Cancel')),
      FilledButton(onPressed: busy ? null : () async {
        if (!form.currentState!.validate()) return;
        setState(() {busy = true; error = null;});
        try {
          PartySnapshot.optional(name.text, phone.text);
          final id = await DuesService().create(accountId: account, receivable: receivable, amountPaise: Money.parse(amount.text),
            description: description.text, dueDate: dueDate == null ? null : dates.DateUtils.formatDate(dueDate!), contactName: name.text, contactPhone: phone.text);
          if (context.mounted) Navigator.pop(context, id);
        } catch (_) {if (mounted) setState(() => error = 'Check the amount, customer and contact details, then retry.');}
        finally {if (mounted) setState(() => busy = false);}
      }, child: Text(busy ? 'Saving…' : 'Save amount due')),
    ]);
}

class _RecordPayment extends StatefulWidget {
  const _RecordPayment({required this.due}); final Map<String, Object?> due;
  @override
  State<_RecordPayment> createState() => _RecordPaymentState();
}
class _RecordPaymentState extends State<_RecordPayment> {
  final amount = TextEditingController(), note = TextEditingController(); final form = GlobalKey<FormState>();
  final key = DuesService.operationKey(); String mode = 'cash'; bool busy = false; String? error;
  @override
  void initState() {super.initState(); amount.text = ((widget.due['remaining_paise'] as int) / 100).toStringAsFixed(2);}
  @override
  void dispose() {amount.dispose(); note.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) => AlertDialog(title: const AppText('Record payment'), content: SingleChildScrollView(child: Form(key: form,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Remaining: ${Money.format(widget.due['remaining_paise'] as int)}'),
      TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment amount (INR)'),
        validator: (v) {try {return Money.parse(v ?? '') > (widget.due['remaining_paise'] as int) ? 'Payment exceeds remaining amount' : null;} catch (_) {return 'Enter a positive amount';}}),
      DropdownButtonFormField<String>(initialValue: mode, decoration: const InputDecoration(labelText: 'Payment mode'),
        items: const [DropdownMenuItem(value: 'cash', child: AppText('Cash')), DropdownMenuItem(value: 'bank', child: AppText('Bank')),
          DropdownMenuItem(value: 'upi', child: AppText('UPI')), DropdownMenuItem(value: 'card', child: AppText('Card'))], onChanged: (v) {if (v != null) mode = v;}),
      TextField(controller: note, maxLength: 2000, decoration: const InputDecoration(label: AppText('Note (optional)'))),
      if (error != null) Text(error!),
    ]))), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const AppText('Cancel')),
      FilledButton(onPressed: busy ? null : () async {
        if (!form.currentState!.validate()) return;
        setState(() {busy = true; error = null;});
        try {
          final id = await DuesService().recordPayment(obligationId: widget.due['id'] as int, amountPaise: Money.parse(amount.text), operationKey: key, mode: mode, note: note.text);
          if (context.mounted) Navigator.pop(context, id);
        } catch (_) {if (mounted) setState(() => error = 'Payment could not be saved. Reload the remaining amount and retry.');}
        finally {if (mounted) setState(() => busy = false);}
      }, child: Text(busy ? 'Saving…' : 'Save payment')),
    ]);
}

class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({required this.obligationId}); final int obligationId;
  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}
class _PaymentHistoryState extends State<_PaymentHistory> {
  late Future<List<Map<String, Object?>>> data;
  @override
  void initState() {super.initState(); data = DuesService().payments(widget.obligationId);}
  Future<void> reverse(int id) async {
    var reason = '';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const AppText('Reverse payment?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const AppText('A matching counter entry will be recorded and the amount due will reopen. The original payment stays in history.'),
        TextField(maxLength: 500, onChanged: (value) => reason = value, decoration: const InputDecoration(labelText: 'Reason (required)')),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const AppText('Cancel')),
        FilledButton(onPressed: () {if (reason.trim().isNotEmpty) Navigator.pop(context, true);}, child: const AppText('Reverse payment'))]));
    if (confirmed != true) return;
    try {await DuesService().reversePayment(id, reason); if (mounted) setState(() {data = DuesService().payments(widget.obligationId);});}
    catch (_) {if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('Payment could not be reversed. Please reload.')));}
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const AppText('Payment history'), content: SizedBox(width: 450,
    child: FutureBuilder(future: data, builder: (context, snapshot) {
      if (snapshot.hasError) return const AppText('Could not load payment history.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (snapshot.data!.isEmpty) const AppText('No recorded payments yet.'),
        for (final p in snapshot.data!) ListTile(title: Text('${Money.format(p['amount_paise'] as int)} · ${p['mode']}'),
          subtitle: Text('${dates.DateUtils.formatIstDateTime(DateTime.parse(p['created_at'] as String))}${p['reversed_at'] == null ? '' : '\nReversed: ${p['reversal_reason']}'}'),
          trailing: PopupMenuButton<String>(enabled: p['reversed_at'] == null, onSelected: (value) {
            if (value == 'reverse') {reverse(p['id'] as int);} else {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => VerifiedShareScreen(draft: WhatsAppDraft(
                type: WhatsAppMessageType.receipt, customer: '', amount: 0, timestampUtc: DateTime.now().toUtc(), sourceIncomeId: p['income_id'] as int))));
            }
          }, itemBuilder: (_) => [
            if (p['reversed_at'] == null) const PopupMenuItem(value: 'reverse', child: AppText('Reverse payment')),
            if (p['income_id'] != null && p['reversed_at'] == null) const PopupMenuItem(value: 'receipt', child: AppText('Share recorded receipt')),
          ])),
      ]));
    })), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('Close'))]);
}
