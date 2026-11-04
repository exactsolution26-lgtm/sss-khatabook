import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}
class _AuditScreenState extends State<AuditScreen> {
  int limit = 200;
  late Future<List<Map<String, Object?>>> rows;
  @override
  void initState() {super.initState(); rows = load();}
  Future<List<Map<String, Object?>>> load() async => (await DBHelper.database).query(
    'app_audit', orderBy: 'occurred_at DESC,rowid DESC', limit: limit);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Audit History')),
    body: FutureBuilder(future: rows, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() {rows = load();}), child: const Text('Could not load history — Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Local device history. Times use the device clock; imported history is not server verified.'),
        if (snapshot.data!.isEmpty) const ListTile(title: Text('No recorded changes yet.')),
        for (final row in snapshot.data!) Card(child: ExpansionTile(
          title: Text('${row['entity']} #${row['record_id'] ?? ''} · ${row['operation']}'),
          subtitle: Text(dates.DateUtils.formatIstDateTime(DateTime.parse(row['occurred_at'] as String))),
          children: [for (final field in ['amount', 'label', 'contact_name', 'contact_phone', 'date', 'mode', 'category'])
            if (row['old_$field'] != null || row['new_$field'] != null)
              ListTile(title: Text(field.replaceAll('_', ' ')),
                subtitle: Text('${row['old_$field'] ?? '—'} → ${row['new_$field'] ?? '—'}'))],
        )),
        if (snapshot.data!.length >= limit) TextButton(onPressed: () => setState(() {limit += 200; rows = load();}), child: const Text('Load older changes')),
      ]);
    }));
}
