import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;
import 'xlsx_export.dart';

class LedgerExport {
  LedgerExport(this.account, this.entries);
  final Map<String, Object?> account;
  final List<Map<String, Object?>> entries;

  static Future<LedgerExport> load(int accountId) async {
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final accounts = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (accounts.length != 1) throw StateError('Account not found');
      final rows = await txn.rawQuery('''SELECT id,amount,date,description AS note,created_at,
        contact_name,contact_phone,category,mode,'income' AS kind FROM income WHERE account_id = ?
        UNION ALL SELECT id,amount,date,note,created_at,contact_name,contact_phone,category,mode,
        'expense' AS kind FROM expenses WHERE account_id = ? ORDER BY date,created_at,kind,id''', [accountId, accountId]);
      return LedgerExport(accounts.single, rows);
    });
  }

  int get openingPaise => ((account['opening_balance'] as num) * 100).round();
  int get incomePaise => entries.where((r) => r['kind'] == 'income')
    .fold(0, (sum, r) => sum + ((r['amount'] as num) * 100).round());
  int get expensePaise => entries.where((r) => r['kind'] == 'expense')
    .fold(0, (sum, r) => sum + ((r['amount'] as num) * 100).round());
  int get closingPaise => openingPaise + incomePaise - expensePaise;
  String money(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 2).format(paise / 100);

  static String csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is! num && RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }
  List<List<Object?>> tabularRows() {
    var running = openingPaise;
    return <List<Object?>>[
      ['Account', account['name']],
      ['Date', 'Type', 'Amount INR', 'Running Balance INR', 'Category', 'Payment Mode',
        'Contact Name', 'Contact Phone', 'Description', 'Saved at IST'],
      ['', 'Opening balance', openingPaise / 100, openingPaise / 100, '', '', '', '', '', ''],
      for (final row in entries) [
        row['date'], row['kind'], row['amount'],
        (running += (row['kind'] == 'income' ? 1 : -1) * ((row['amount'] as num) * 100).round()) / 100,
        row['category'], row['mode'], row['contact_name'], row['contact_phone'], row['note'],
        row['created_at'] == null ? 'Unknown historic save time'
          : dates.DateUtils.formatIstDateTime(DateTime.parse(row['created_at'] as String)),
      ],
    ];
  }
  Uint8List csv() => Uint8List.fromList(utf8.encode('\ufeff${tabularRows().map((r) => r.map(csvCell).join(',')).join('\r\n')}'));
  Uint8List xlsx() => XlsxExport.write(tabularRows());

  Future<Uint8List> pdf() async {
    final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final hindi = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'));
    final document = pw.Document(theme: pw.ThemeData.withFont(base: latin, bold: latin, fontFallback: [hindi]));
    var running = openingPaise;
    final rows = <List<String>>[
      ['', 'Opening balance', '', '', money(openingPaise)],
      for (final row in entries) [
        row['date'] as String,
        [row['category'], if (row['contact_name'] != null) '${row['contact_name']} · ${row['contact_phone']}',
          if (row['note'] != null) (row['note'] as String).length > 500
            ? '${(row['note'] as String).substring(0, 500)}…' : row['note'],
          if (row['created_at'] != null) 'Saved: ${dates.DateUtils.formatIstDateTime(DateTime.parse(row['created_at'] as String))}',
        ].where((s) => s != null && s.toString().isNotEmpty).join('\n'),
        row['kind'] == 'income' ? money(((row['amount'] as num) * 100).round()) : '',
        row['kind'] == 'expense' ? money(((row['amount'] as num) * 100).round()) : '',
        money(running += (row['kind'] == 'income' ? 1 : -1) * ((row['amount'] as num) * 100).round()),
      ],
    ];
    document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, maxPages: 10000,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('SSS Khatabook — Customer Ledger', style: pw.TextStyle(fontSize: 18)),
        pw.Text(account['name'] as String), pw.SizedBox(height: 12),
      ]),
      footer: (context) => pw.Text('Page ${context.pageNumber} / ${context.pagesCount} · Generated ${dates.DateUtils.formatIstDateTime(DateTime.now().toUtc())}',
        style: const pw.TextStyle(fontSize: 8)),
      build: (_) => [
        pw.Text('Income: ${money(incomePaise)}   Expenses: ${money(expensePaise)}   Closing: ${money(closingPaise)}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(headers: ['Date', 'Details', 'Income', 'Expense', 'Balance'], data: rows,
          cellStyle: const pw.TextStyle(fontSize: 8), headerStyle: pw.TextStyle(fontSize: 9),
          columnWidths: {0: const pw.FlexColumnWidth(1.1), 1: const pw.FlexColumnWidth(3.4),
            2: const pw.FlexColumnWidth(1.3), 3: const pw.FlexColumnWidth(1.3), 4: const pw.FlexColumnWidth(1.3)},
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200)),
        pw.SizedBox(height: 12), pw.Text('Descriptions over 500 characters are shortened in this PDF; CSV retains the full description. Unknown historic save times remain unknown.', style: const pw.TextStyle(fontSize: 8)),
      ],
    ));
    return document.save();
  }
}
