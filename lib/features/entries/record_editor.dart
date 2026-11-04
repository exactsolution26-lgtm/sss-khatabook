import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;
import 'record_recovery.dart';
import 'contact_fields.dart';
import 'category_field.dart';

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key,required this.income,required this.id,required this.accountId});
  final bool income;
  final int id,accountId;
  @override State<RecordEditor> createState() => _RecordEditorState();
}
class _RecordEditorState extends State<RecordEditor> {
  final amount = TextEditingController(), note = TextEditingController(), category = TextEditingController();
  final name = TextEditingController(), phone = TextEditingController();
  String mode = 'cash'; DateTime date = dates.DateUtils.indiaToday();
  bool loading = true,busy = false; String? error,savedAt;
  @override void initState() {super.initState(); load();}
  Future<void> load() async {
    try {
      final row = (await (await DBHelper.database).query(RecordRecovery.table(widget.income),where: 'id=? AND account_id=?',whereArgs: [widget.id,widget.accountId])).single;
      if (!mounted) return;
      amount.text = (row['amount'] as num).toStringAsFixed(2); note.text = row[widget.income ? 'description' : 'note'] as String? ?? '';
      category.text = row['category'] as String? ?? 'Other'; name.text = row['contact_name'] as String? ?? ''; phone.text = row['contact_phone'] as String? ?? '';
      mode = row['mode'] as String? ?? 'cash'; date = DateTime.parse(row['date'] as String); savedAt = row['created_at'] as String?;
      setState(() => loading = false);
    } catch (_) {if (mounted) setState(() {loading=false;error='Could not load entry';});}
  }
  @override void dispose() {for(final c in [amount,note,category,name,phone]) {c.dispose();} super.dispose();}
  Future<void> save() async {
    if (busy) return; setState(() {busy=true;error=null;}); FocusScope.of(context).unfocus();
    try {
      await RecordRecovery.edit(income: widget.income,id: widget.id,accountId: widget.accountId,
        amount: amount.text,date: dates.DateUtils.formatDate(date),note: note.text,category: category.text,mode: mode,name: name.text,phone: phone.text);
      if(mounted) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved ✓'))); Navigator.pop(context,true);}
    } catch (_) {if(mounted) setState(() => error='Could not save. Check fields. Allocated payments must be reversed in Payment History.');}
    finally {if(mounted) setState(() => busy=false);}
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Edit ${widget.income ? 'Income' : 'Expense'}')),
    body: loading ? const Center(child: CircularProgressIndicator()) : AbsorbPointer(absorbing: busy,child: ListView(padding: const EdgeInsets.all(20),children: [
      if(savedAt != null) Text('Originally saved: ${dates.DateUtils.formatIstDateTime(DateTime.parse(savedAt!))}'),
      const SizedBox(height: 16),
      TextField(controller: amount,keyboardType: const TextInputType.numberWithOptions(decimal: true),decoration: const InputDecoration(labelText: 'Amount')),
      const SizedBox(height: 16), CategoryField(income: widget.income,initialValue: category.text,onChanged: (v) => category.text=v),
      const SizedBox(height: 16), DropdownButtonFormField<String>(initialValue: mode,decoration: const InputDecoration(labelText: 'Payment mode'),
        items: {mode,'cash','online','bank','upi','card'}.map((m) => DropdownMenuItem(value: m,child: Text(m))).toList(),onChanged: (m) {if(m!=null) setState(() => mode=m);}),
      const SizedBox(height: 16),ContactFields(name: name,phone: phone),
      const SizedBox(height: 16),TextField(controller: note,maxLines: 3,decoration: const InputDecoration(labelText: 'Notes / Description')),
      ListTile(title: const Text('Transaction date'),subtitle: Text(dates.DateUtils.formatDisplayDate(date)),trailing: const Icon(Icons.calendar_today),onTap: () async {
        final selected=await showDatePicker(context: context,initialDate: date,firstDate: DateTime(2000),lastDate: dates.DateUtils.indiaToday());
        if(selected!=null && mounted) setState(() => date=selected);
      }),
      const Text('The original save time is preserved. Changes are recorded in Audit History.'),
      if(error!=null) Text(error!,style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 20),FilledButton(onPressed: busy ? null : save,child: Text(busy ? 'Saving…' : 'Save changes')),
    ])));
}

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key,this.accountId}); final int? accountId;
  @override State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}
class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late Future<List<Map<String,Object?>>> rows;
  @override void initState() {super.initState();reload();}
  void reload() {rows=RecordRecovery.list(accountId: widget.accountId);}
  Future<void> restore(Map<String,Object?> row) async {
    try {await RecordRecovery.restore(row['id'] as int,row['account_id'] as int);if(mounted) {setState(reload);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry restored ✓')));}}
    catch(_) {if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not restore. The record may already exist.')));}
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Deleted Entries')),
    body: FutureBuilder<List<Map<String,Object?>>>(future: rows,builder: (context,snapshot) {
      if(snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(reload),child: const Text('Could not load — Retry')));
      if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if(snapshot.data!.isEmpty) return const Center(child: Text('No deleted entries.'));
      return ListView(children: snapshot.data!.map((r) => Card(child: ListTile(title: Text('${r['kind']} #${r['record_id']}'),
        subtitle: Text('${r['reason']}\n${dates.DateUtils.formatIstDateTime(DateTime.parse(r['deleted_at'] as String))}'),
        trailing: TextButton(onPressed: () => restore(r),child: const Text('Restore'))))).toList());
    }));
}
