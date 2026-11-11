import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;
import 'xlsx_export.dart';
import '../history/transaction_history.dart';
import '../workspace/workspace_store.dart';

class LedgerExport {
  LedgerExport(this.account, this.entries);
  final Map<String, Object?> account;
  final List<Map<String, Object?>> entries;

  static Future<LedgerExport> load(int accountId,{String? fromDate,String? toDate}) async {
    for(final value in [fromDate,toDate]) {
      if(value!=null && (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) || DateTime.tryParse(value)==null || dates.DateUtils.formatDate(DateTime.parse(value))!=value)) throw ArgumentError('Invalid report date');
    }
    if(fromDate!=null && toDate!=null && fromDate.compareTo(toDate)>0) throw ArgumentError('Report dates are reversed');
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final accounts = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (accounts.length != 1) throw StateError('Account not found');
      final rows = await txn.rawQuery('''SELECT id,amount,date,description AS note,created_at,
        contact_name,contact_phone,category,mode,'income' AS kind FROM income WHERE account_id = ?
        UNION ALL SELECT id,amount,date,note,created_at,contact_name,contact_phone,category,mode,
        'expense' AS kind FROM expenses WHERE account_id = ? ORDER BY date,created_at,kind,id''', [accountId, accountId]);
      var opening=((accounts.single['opening_balance'] as num)*100).round();
      final filtered=<Map<String,Object?>>[];
      for(final row in rows) {
        final date=row['date'] as String;
        if(fromDate!=null && date.compareTo(fromDate)<0) {
          opening+=(row['kind']=='income' ? 1 : -1)*amountPaise(row);
        } else if(toDate==null || date.compareTo(toDate)<=0) {filtered.add(row);}
      }
      return LedgerExport({...accounts.single,'opening_balance': opening/100,'from_date': fromDate,'to_date': toDate}, filtered);
    });
  }

  static int amountPaise(Map<String, Object?> row) =>
      ((row['amount'] as num) * 100).round();

  int get openingPaise => ((account['opening_balance'] as num) * 100).round();
  int get incomePaise => entries.where((r) => r['kind'] == 'income')
    .fold(0, (sum, r) => sum + amountPaise(r));
  int get expensePaise => entries.where((r) => r['kind'] == 'expense')
    .fold(0, (sum, r) => sum + amountPaise(r));
  int get closingPaise => openingPaise + incomePaise - expensePaise;
  Iterable<(Map<String, Object?>, int)> get runningRows sync* {
    var running = openingPaise;
    for (final row in entries) {
      final paise = amountPaise(row);
      running += row['kind'] == 'income' ? paise : -paise;
      yield (row, running);
    }
  }
  String money(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 2).format(paise / 100);

  static String csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is! num && RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }
  List<List<Object?>> tabularRows() {
    return <List<Object?>>[
      ['Account', account['name']],
      if(account['from_date']!=null || account['to_date']!=null) ['Period', '${account['from_date'] ?? 'Beginning'} to ${account['to_date'] ?? 'Latest'}'],
      ['Date', 'Type', 'Amount INR', 'Running Balance INR', 'Category', 'Payment Mode',
        'Contact Name', 'Contact Phone', 'Description', 'Saved time (IST when verified)'],
      ['', 'Opening balance', openingPaise / 100, openingPaise / 100, '', '', '', '', '', ''],
      for (final (row, running) in runningRows) [
        row['date'], row['kind'], amountPaise(row) / 100,
        running / 100,
        row['category'], row['mode'], row['contact_name'], row['contact_phone'], row['note'],
        HistoryEntry.timestamp(row['created_at']),
      ],
    ];
  }
  Uint8List csv() => Uint8List.fromList(utf8.encode('\ufeff${tabularRows().map((r) => r.map(csvCell).join(',')).join('\r\n')}'));
  Uint8List xlsx() => XlsxExport.write(tabularRows());

  static final _devanagari = RegExp(r'[ऀ-ॿ꣠-ꣿ]');
  static const _latinFamily = 'LedgerExportLatin';
  static const _hindiFamily = 'LedgerExportDevanagari';
  static Future<void>? _pdfFonts;

  // Flutter shapes Devanagari conjuncts and vowel marks before embedding the
  // image. The PDF font fallback alone only supplies the individual glyphs.
  static Future<pw.Widget> _pdfText(
    String text, {
    required double width,
    required double size,
  }) async {
    if (!_devanagari.hasMatch(text)) {
      return pw.Text(text, style: pw.TextStyle(fontSize: size));
    }
    await (_pdfFonts ??= Future.wait<void>([
      (FontLoader(_latinFamily)
            ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
          .load(),
      (FontLoader(_hindiFamily)
            ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf')))
          .load(),
    ]).then<void>((_) {}));
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const ui.Color(0xff000000),
          fontSize: size,
          fontFamily: _latinFamily,
          fontFamilyFallback: const [_hindiFamily],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    const scale = 3.0;
    try {
      painter.layout(maxWidth: width);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(scale);
      painter.paint(canvas, ui.Offset.zero);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          (painter.width * scale).ceil(), (painter.height * scale).ceil(),
        );
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) throw StateError('Could not render ledger text');
          return pw.Image(
            pw.MemoryImage(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes)),
            width: image.width / scale,
            height: image.height / scale,
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      painter.dispose();
    }
  }

  Future<Uint8List> pdf() async {
    final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final hindi = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'));
    final business=await WorkspaceStore.profile();
    final document = pw.Document(theme: pw.ThemeData.withFont(base: latin, bold: latin, fontFallback: [hindi]));
    final rows = <List<Object>>[
      ['', 'Opening balance', '', '', money(openingPaise)],
      for (final (row, running) in runningRows) [
        row['date'] as String,
        [row['category'], if (row['contact_name'] != null) '${row['contact_name']} · ${row['contact_phone']}',
          if (row['note'] != null) (row['note'] as String).length > 500
            ? '${(row['note'] as String).substring(0, 500)}…' : row['note'],
          if (row['created_at'] != null) 'Saved: ${HistoryEntry.timestamp(row['created_at'])}',
        ].where((s) => s != null && s.toString().isNotEmpty).join('\n'),
        row['kind'] == 'income' ? money(amountPaise(row)) : '',
        row['kind'] == 'expense' ? money(amountPaise(row)) : '',
        money(running),
      ],
    ];
    const margin = 28.0;
    final pageWidth = PdfPageFormat.a4.width - 2 * margin;
    final accountName = await _pdfText(account['name'] as String, width: pageWidth, size: 12);
    final businessName = business == null ? null : await _pdfText(
      business['name'] as String, width: pageWidth, size: 16,
    );
    // Match the Details flex column minus the table's default cell padding.
    final detailsWidth = (pageWidth * 3.4 / 8.4 - 10).floorToDouble();
    for (final row in rows) {
      final details = row[1] as String;
      if (_devanagari.hasMatch(details)) {
        row[1] = await _pdfText(details, width: detailsWidth, size: 8);
      }
    }
    document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, maxPages: 10000,
      margin: const pw.EdgeInsets.all(margin),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (businessName != null) businessName,
        pw.Text('SSS Khatabook — Customer Ledger', style: pw.TextStyle(fontSize: 18)),
        accountName,
        if(account['from_date']!=null || account['to_date']!=null) pw.Text('Period: ${account['from_date'] ?? 'Beginning'} to ${account['to_date'] ?? 'Latest'}'),
        pw.SizedBox(height: 12),
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
