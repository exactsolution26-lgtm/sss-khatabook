import '../../core/localization/app_text.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/utils/file_actions.dart';
import 'ledger_export.dart';
import '../../core/utils/date_utils.dart' as dates;

class LedgerExportScreen extends StatefulWidget {
  const LedgerExportScreen({super.key, required this.accountId});
  final int accountId;
  @override
  State<LedgerExportScreen> createState() => _LedgerExportScreenState();
}
class _LedgerExportScreenState extends State<LedgerExportScreen> {
  late Future<(LedgerExport, Uint8List)> report;
  String? fromDate,toDate;
  @override
  void initState() {super.initState(); report = load();}
  Future<(LedgerExport, Uint8List)> load() async {
    final ledger = await LedgerExport.load(widget.accountId,fromDate: fromDate,toDate: toDate);
    return (ledger, await ledger.pdf());
  }
  Future<void> period(String type) async {
    if(type=='all') {setState(() {fromDate=null;toDate=null;report=load();});return;}
    final today=dates.DateUtils.indiaToday();
    if(type=='custom') {
      final range=await showDateRangePicker(context: context,firstDate: DateTime(2000),lastDate: today);
      if(range==null || !mounted) return;
      setState(() {fromDate=dates.DateUtils.formatDate(range.start);toDate=dates.DateUtils.formatDate(range.end);report=load();});return;
    }
    final day=await showDatePicker(context: context,initialDate: today,firstDate: DateTime(2000),lastDate: today);
    if(day==null || !mounted) return;
    setState(() {
      fromDate=dates.DateUtils.formatDate(DateTime(day.year,type=='year' ? 1 : day.month));
      toDate=dates.DateUtils.formatDate(type=='year' ? DateTime(day.year,12,31) : DateTime(day.year,day.month+1,0));report=load();
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const AppText('Ledger & Statements'),actions: [PopupMenuButton<String>(tooltip: 'Statement period',onSelected: period,itemBuilder: (_) => const [
      PopupMenuItem(value: 'all',child: AppText('All time')),PopupMenuItem(value: 'month',child: AppText('Monthly statement')),PopupMenuItem(value: 'year',child: AppText('Yearly statement')),PopupMenuItem(value: 'custom',child: AppText('Custom date range'))])]),
    body: FutureBuilder(future: report, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() {report = load();}), child: const Text('Could not create ledger — Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final (ledger, bytes) = snapshot.data!;
      return Column(children: [
        if(fromDate!=null || toDate!=null) Padding(padding: const EdgeInsets.all(8),child: Text('$fromDate to $toDate · opening includes earlier transactions')),
        Wrap(spacing: 8, children: [
          TextButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const AppText('Download / Share PDF'),
            onPressed: () => share(context, bytes, 'pdf', 'application/pdf')),
          TextButton.icon(icon: const Icon(Icons.table_chart_outlined), label: const AppText('Download / Share CSV'),
            onPressed: () => share(context, ledger.csv(), 'csv', 'text/csv')),
          TextButton.icon(icon: const Icon(Icons.grid_on_outlined), label: const AppText('Download / Share Excel'),
            onPressed: () => share(context, ledger.xlsx(), 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
        ]),
        Expanded(child: PdfPreview(build: (_) async => bytes, canChangePageFormat: false,
          canChangeOrientation: false, allowSharing: false, allowPrinting: true)),
      ]);
    }));
  Future<void> share(BuildContext context, Uint8List bytes, String extension, String mime) async {
    try {await shareFile(context, bytes, 'sss-ledger-${widget.accountId}.$extension', mime);}
    catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('Could not open file sharing. Please retry.')));}
  }
}
