import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/utils/file_actions.dart';
import 'ledger_export.dart';

class LedgerExportScreen extends StatefulWidget {
  const LedgerExportScreen({super.key, required this.accountId});
  final int accountId;
  @override
  State<LedgerExportScreen> createState() => _LedgerExportScreenState();
}
class _LedgerExportScreenState extends State<LedgerExportScreen> {
  late Future<(LedgerExport, Uint8List)> report;
  @override
  void initState() {super.initState(); report = load();}
  Future<(LedgerExport, Uint8List)> load() async {
    final ledger = await LedgerExport.load(widget.accountId);
    return (ledger, await ledger.pdf());
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Ledger PDF & CSV')),
    body: FutureBuilder(future: report, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => report = load()), child: const Text('Could not create ledger — Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final (ledger, bytes) = snapshot.data!;
      return Column(children: [
        Wrap(spacing: 8, children: [
          TextButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Download / Share PDF'),
            onPressed: () => share(context, bytes, 'pdf', 'application/pdf')),
          TextButton.icon(icon: const Icon(Icons.table_chart_outlined), label: const Text('Download / Share CSV'),
            onPressed: () => share(context, ledger.csv(), 'csv', 'text/csv')),
          TextButton.icon(icon: const Icon(Icons.grid_on_outlined), label: const Text('Download / Share Excel'),
            onPressed: () => share(context, ledger.xlsx(), 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
        ]),
        Expanded(child: PdfPreview(build: (_) async => bytes, canChangePageFormat: false,
          canChangeOrientation: false, allowSharing: false, allowPrinting: true)),
      ]);
    }));
  Future<void> share(BuildContext context, Uint8List bytes, String extension, String mime) async {
    try {await shareFile(context, bytes, 'sss-ledger-${widget.accountId}.$extension', mime);}
    catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file sharing. Please retry.')));}
  }
}
