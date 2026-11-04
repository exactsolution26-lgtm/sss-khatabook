import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../../core/utils/file_actions.dart';
import '../../core/utils/money.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../entries/attachment_widgets.dart';
import '../entries/record_editor.dart';
import '../entries/record_recovery.dart';
import '../settings/app_settings.dart';
import '../whatsapp/verified_share_screen.dart';
import '../whatsapp/whatsapp_share_service.dart';
import 'transaction_history.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.income, required this.id, required this.accountId});
  final bool income;
  final int id, accountId;
  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Future<List<HistoryEntry>> entry;
  bool busy = false;
  bool get hindi => SettingsScope.of(context).language.name == 'hindi';
  String t(String en, String hi) => hindi ? hi : en;
  @override
  void initState() { super.initState(); reload(); }
  void reload() => entry = TransactionHistory.load(widget.income, id: widget.id, accountId: widget.accountId);
  void error(String en, String hi) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(en, hi))));
  }

  Future<void> edit() async {
    await Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => RecordEditor(
      income: widget.income, id: widget.id, accountId: widget.accountId)));
    if (mounted) setState(reload);
  }

  Future<void> remove() async {
    final reason = await showDialog<String>(context: context, builder: (_) => _HistoryDeleteDialog(hindi: hindi));
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await RecordRecovery.remove(income: widget.income, id: widget.id,
        accountId: widget.accountId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(
          'Entry deleted. Restore it from Deleted Entries in the account ledger.',
          'एंट्री हटाई गई। खाते के Deleted Entries से वापस ला सकते हैं।'))));
        Navigator.pop(context);
      }
    } catch (_) {
      error('Could not delete. Allocated payments must be reversed in Payment History.',
        'हटाया नहीं जा सका। जुड़े भुगतान Payment History से रिवर्स करें।');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> receipt() async {
    setState(() => busy = true);
    try {
      // Re-read immediately before export; a deleted record cannot produce a receipt.
      final current = (await TransactionHistory.load(widget.income,
        id: widget.id, accountId: widget.accountId)).single;
      final bytes = await TransactionReceipt.pdf(current);
      if (mounted) await shareFile(context, bytes, '${current.reference}-receipt.pdf', 'application/pdf');
    } catch (_) { error('Could not export this entry.', 'यह एंट्री एक्सपोर्ट नहीं हुई।'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Entry details', 'एंट्री विवरण'))),
    body: FutureBuilder<List<HistoryEntry>>(
      future: entry,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(reload),
          child: Text(t('Could not load entry — Retry', 'एंट्री नहीं खुली — फिर कोशिश करें'))));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(t(
          'This entry is no longer available in this account.', 'इस खाते में अब यह एंट्री उपलब्ध नहीं है।')));
        final e = snapshot.data!.single;
        Widget field(String label, String value) => ListTile(contentPadding: EdgeInsets.zero,
          title: Text(label, style: Theme.of(context).textTheme.labelMedium),
          subtitle: SelectableText(value));
        return ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: Text(widget.income ? t('Income received', 'आय प्राप्त') : t('Expense paid', 'खर्च किया'))),
          const SizedBox(height: 8),
          Center(child: Text('${widget.income ? '+' : '−'}${Money.format(e.paise)}',
            style: Theme.of(context).textTheme.headlineMedium)),
          const SizedBox(height: 16),
          field(t('Transaction date', 'लेन-देन की तारीख'), dates.DateUtils.formatIstDateTime(
            DateTime.parse('${e.date}T00:00:00+05:30')).split(' · ').first),
          field(t('Saved at · India time', 'सेव किया · भारत समय'), HistoryEntry.timestamp(e.row['created_at'])),
          field(t('Customer / party', 'ग्राहक / पार्टी'), e.name.isEmpty ? t('No contact linked', 'संपर्क नहीं जुड़ा') : e.name),
          field(t('Mobile number', 'मोबाइल नंबर'), e.phone.isEmpty ? '—' : e.phone),
          field(t('Account', 'खाता'), e.account),
          field(t('Category', 'श्रेणी'), e.category),
          field(t('Payment mode', 'भुगतान माध्यम'), e.mode),
          field(t('Notes / Description', 'नोट / विवरण'), e.note.isEmpty ? '—' : e.note),
          field(t('Entry ID', 'एंट्री आईडी'), e.reference),
          field(t('Last edited', 'अंतिम बदलाव'), e.row['updated_at'] == null
            ? t('No edits', 'कोई बदलाव नहीं') : HistoryEntry.timestamp(e.row['updated_at'])),
          OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => AttachmentScreen(entryId: widget.id, income: widget.income))),
            icon: const Icon(Icons.attach_file), label: Text('${t('Attachments', 'अटैचमेंट')} (${e.attachmentCount})')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: busy ? null : edit, icon: const Icon(Icons.edit_outlined), label: Text(t('Edit entry', 'एंट्री बदलें'))),
            OutlinedButton.icon(onPressed: busy ? null : remove, icon: const Icon(Icons.delete_outline), label: Text(t('Delete entry', 'एंट्री हटाएँ'))),
            OutlinedButton.icon(onPressed: busy ? null : receipt, icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(t('Receipt PDF', 'रसीद PDF'))),
            OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => VerifiedShareScreen(draft: WhatsAppDraft(
                type: WhatsAppMessageType.receipt, customer: '', amount: 0, timestampUtc: DateTime.now().toUtc(),
                sourceAccountId: widget.accountId,
                sourceIncomeId: widget.income ? widget.id : null,
                sourceExpenseId: widget.income ? null : widget.id)))),
              icon: const Icon(Icons.chat_outlined), label: Text(t('WhatsApp · optional', 'WhatsApp · वैकल्पिक'))),
          ]),
          if (busy) const LinearProgressIndicator(),
        ]);
      },
    ),
  );
}

class TransactionReceipt {
  static Future<Uint8List> pdf(HistoryEntry entry) async {
    final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final hindi = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: latin, bold: latin, fontFallback: [hindi]));
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, maxPages: 20, build: (_) => [
      pw.Text('SSS Khatabook — Transaction receipt', style: const pw.TextStyle(fontSize: 20)),
      pw.SizedBox(height: 18),
      pw.Text('${entry.reference} · ${entry.income ? 'Income received' : 'Expense paid'}'),
      pw.Text('INR ${(entry.paise / 100).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 24)),
      pw.SizedBox(height: 16),
      for (final line in [
        'Transaction date: ${entry.date}',
        'Saved: ${HistoryEntry.timestamp(entry.row['created_at'])}',
        'Account: ${entry.account}', 'Customer / party: ${entry.name.isEmpty ? 'No contact linked' : entry.name}',
        'Mobile: ${entry.phone.isEmpty ? 'Not recorded' : entry.phone}',
        'Category: ${entry.category}', 'Payment mode: ${entry.mode}',
        'Last edited: ${entry.row['updated_at'] == null ? 'No edits' : HistoryEntry.timestamp(entry.row['updated_at'])}',
        'Notes: ${entry.note}',
      ]) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: pw.Text(line)),
      pw.SizedBox(height: 18),
      pw.Text('Generated: ${dates.DateUtils.formatIstDateTime(DateTime.now().toUtc())}'),
      pw.Text('Based on a locally recorded transaction; not independent payment verification.'),
    ]));
    return doc.save();
  }
}

class _HistoryDeleteDialog extends StatefulWidget {
  const _HistoryDeleteDialog({required this.hindi});
  final bool hindi;
  @override
  State<_HistoryDeleteDialog> createState() => _HistoryDeleteDialogState();
}
class _HistoryDeleteDialogState extends State<_HistoryDeleteDialog> {
  final reason = TextEditingController();
  @override
  void dispose() { reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.hindi ? 'यह एंट्री हटाएँ?' : 'Delete this entry?'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.hindi ? 'बैलेंस फिर से गणना होगा। एंट्री और अटैचमेंट Deleted Entries से वापस आ सकते हैं।'
        : 'The balance will be recalculated. This entry and its attachments remain recoverable in Deleted Entries.'),
      TextField(controller: reason, maxLength: 500, onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: widget.hindi ? 'कारण (ज़रूरी)' : 'Reason (required)')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.hindi ? 'रद्द करें' : 'Cancel')),
      FilledButton(onPressed: reason.text.trim().isEmpty ? null : () => Navigator.pop(context, reason.text.trim()),
        child: Text(widget.hindi ? 'हटाएँ' : 'Delete'))],
  );
}
