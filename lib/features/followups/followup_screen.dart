import 'package:flutter/material.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../../core/utils/date_utils.dart' as dates;
import 'followup_service.dart';

class FollowupScreen extends StatefulWidget {
  const FollowupScreen({super.key, this.accountId, this.obligationId}); final int? accountId, obligationId;
  @override
  State<FollowupScreen> createState() => _FollowupScreenState();
}
class _FollowupScreenState extends State<FollowupScreen> {
  final service = FollowupService(); late Future<List<Map<String, Object?>>> rows;
  bool completed = false;
  @override
  void initState() {super.initState(); rows = service.list(accountId: widget.accountId);}
  void refresh() {if (mounted) setState(() {rows = service.list(accountId: widget.accountId);});}
  Future<void> create() async {
    try {
      final accounts = await AccountTable.getAllAccounts();
      if (!mounted) return;
      await showDialog<int>(context: context, builder: (_) => _NewFollowup(accounts: accounts,
        accountId: widget.accountId, obligationId: widget.obligationId)); refresh();
    } catch (_) {if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open follow-up form.')));}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Follow-ups & Reminders'), actions: [
    IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh)),
  ]), floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Add Follow-up')),
    body: FutureBuilder(future: rows, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Could not load follow-ups — Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final visible = snapshot.data!.where((r) => (r['status'] == 'done') == completed).toList();
      return ListView(padding: const EdgeInsets.fromLTRB(20,20,20,100), children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show completed follow-ups'), value: completed,
          onChanged: (v) => setState(() => completed = v)),
        if (visible.isEmpty) const ListTile(title: Text('No follow-ups in this view.')),
        for (final row in visible) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row['title'] as String, style: Theme.of(context).textTheme.titleLarge),
          if (row['account_name'] != null) Text(row['account_name'] as String),
          Text(dates.DateUtils.formatIstDateTime(DateTime.parse(row['due_at'] as String))),
          if (row['status'] == 'open' && DateTime.parse(row['due_at'] as String).isBefore(DateTime.now().toUtc())) const Text('Overdue'),
          if ((row['note'] as String).isNotEmpty) Text(row['note'] as String),
          Text(row['notification_scheduled'] == 1 ? 'Device reminder scheduled' : 'Available in the app'),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () async {
              try {await service.setDone(row['id'] as int, !completed); refresh();}
              catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update follow-up.')));}
            }, child: Text(completed ? 'Reopen' : 'Mark done')),
            if (!completed && row['notification_scheduled'] != 1) TextButton(onPressed: () async {
              bool scheduled;
              try {scheduled = await service.enableReminder(row['id'] as int);} catch (_) {scheduled = false;}
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(scheduled
                ? 'Device reminder scheduled. Delivery depends on phone settings.'
                : 'Device reminder unavailable. Your follow-up remains in the app.'))); refresh();
            }, child: const Text('Enable device reminder')),
          ]),
        ]))),
      ]);
    }));
}

class _NewFollowup extends StatefulWidget {
  const _NewFollowup({required this.accounts,this.accountId,this.obligationId});
  final List<AccountModel> accounts; final int? accountId,obligationId;
  @override
  State<_NewFollowup> createState() => _NewFollowupState();
}
class _NewFollowupState extends State<_NewFollowup> {
  final title = TextEditingController(), note = TextEditingController(); final form = GlobalKey<FormState>();
  late int? account; DateTime day = dates.DateUtils.indiaToday(); late TimeOfDay time;
  bool notify = false, busy = false; String? error;
  @override
  void initState() {super.initState(); account = widget.accountId;
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5,minutes: 30)); time = TimeOfDay(hour: ist.hour,minute: ist.minute);}
  @override
  void dispose() {title.dispose(); note.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Add follow-up'), content: SizedBox(width: 450,
    child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<int>(initialValue: account ?? 0, isExpanded: true, decoration: const InputDecoration(labelText: 'Customer / Account (optional)'),
        items: [const DropdownMenuItem(value: 0, child: Text('General reminder')),
          for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
        onChanged: widget.obligationId != null ? null : (v) => account = v == 0 ? null : v),
      TextFormField(controller: title, maxLength: 200, decoration: const InputDecoration(labelText: 'Follow-up title'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null),
      TextField(controller: note, maxLength: 2000, decoration: const InputDecoration(labelText: 'Note (optional)')),
      TextButton.icon(icon: const Icon(Icons.calendar_today), label: Text(dates.DateUtils.formatDisplayDate(day)), onPressed: () async {
        final value = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (mounted && value != null) setState(() => day = value);
      }),
      TextButton.icon(icon: const Icon(Icons.schedule), label: Text('${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')} IST'), onPressed: () async {
        final value = await showTimePicker(context: context, initialTime: time); if (mounted && value != null) setState(() => time = value);
      }),
      CheckboxListTile(value: notify,onChanged: (v) => setState(() => notify = v ?? false),title: const Text('Device reminder (optional)'),
        subtitle: const Text('Your phone may request notification permission. Customer details are hidden in notifications.')),
      if (error != null) Text(error!),
    ])))), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: busy ? null : () async {
        if (!form.currentState!.validate()) return;
        setState(() {busy = true; error = null;});
        try {
          final due = DateTime.utc(day.year,day.month,day.day,time.hour,time.minute).subtract(const Duration(hours: 5,minutes: 30));
          final id = await FollowupService().create(accountId: account,obligationId: widget.obligationId,title: title.text,note: note.text,dueAtUtc: due,notify: notify);
          if (context.mounted) Navigator.pop(context,id);
        } catch (_) {if (mounted) setState(() => error = 'Follow-up could not be saved. Check the details and retry.');}
        finally {if (mounted) setState(() => busy = false);}
      }, child: Text(busy ? 'Saving…' : 'Save follow-up')),
    ]);
}
