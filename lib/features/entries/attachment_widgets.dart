import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../database/db_helper.dart';
import '../../core/utils/file_actions.dart';
import 'attachments.dart';

class AttachmentPicker extends StatefulWidget {
  const AttachmentPicker({super.key, required this.selected});
  final ValueNotifier<List<PendingAttachment>> selected;
  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}
class _AttachmentPickerState extends State<AttachmentPicker> {
  bool picking = false;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: widget.selected, builder: (context, list, _) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(onPressed: picking ? null : () async {
        setState(() => picking = true);
        try {
          final chosen = await files.openFiles(acceptedTypeGroups: [const files.XTypeGroup(label: 'PDF / JPG / PNG',
            extensions: ['pdf','jpg','jpeg','png'], mimeTypes: ['application/pdf','image/jpeg','image/png'],
            uniformTypeIdentifiers: ['com.adobe.pdf','public.jpeg','public.png'])]);
          final next = [...widget.selected.value];
          if (next.length + chosen.length > 5) throw const FormatException('At most 5 attachments');
          for (final file in chosen) {
            if (await file.length() > 5 * 1024 * 1024) throw const FormatException('Each file must be at most 5 MB');
            next.add(await PendingAttachment.inspect(file.name, await file.readAsBytes()));
          }
          if (next.fold<int>(0, (sum, f) => sum + f.bytes.length) > 10 * 1024 * 1024) throw const FormatException('At most 10 MB per entry');
          if (mounted) widget.selected.value = next;
        } catch (_) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose up to 5 PDF/JPG/PNG files, 5 MB each and 10 MB in total.')));
        } finally {if (mounted) setState(() => picking = false);}
      }, icon: const Icon(Icons.attach_file), label: Text(picking ? 'Opening files…' : 'Add Attachments (optional)')),
      for (var i = 0; i < list.length; i++) ListTile(title: Text(list[i].name),
        subtitle: Text('${(list[i].bytes.length / 1024).ceil()} KB'),
        trailing: IconButton(tooltip: 'Remove attachment', icon: const Icon(Icons.close),
          onPressed: () => widget.selected.value = [...list]..removeAt(i))),
    ]));
}

class AttachmentScreen extends StatefulWidget {
  const AttachmentScreen({super.key, required this.entryId, required this.income});
  final int entryId; final bool income;
  @override
  State<AttachmentScreen> createState() => _AttachmentScreenState();
}
class _AttachmentScreenState extends State<AttachmentScreen> {
  late Future<List<Map<String, Object?>>> files;
  @override
  void initState() {super.initState(); files = load();}
  Future<List<Map<String, Object?>>> load() async => (await DBHelper.database).query('attachments',
    columns: ['id','name','mime_type','size_bytes'], where: '${widget.income ? 'income_id' : 'expense_id'} = ?', whereArgs: [widget.entryId]);
  Future<void> open(int id) async {
    try {
      final rows = await (await DBHelper.database).query('attachments',
        where: 'id = ? AND ${widget.income ? 'income_id' : 'expense_id'} = ?', whereArgs: [id, widget.entryId]);
      if (rows.length != 1) throw StateError('Attachment missing');
      final row = rows.single;
      final bytes = base64Decode(row['content_base64'] as String);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _AttachmentView(
        bytes: bytes, name: row['name'] as String, mime: row['mime_type'] as String)));
    } catch (_) {if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open attachment.')));}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Attachments')),
    body: FutureBuilder(future: files, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => files = load()), child: const Text('Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.isEmpty) return const Center(child: Text('No attachments for this entry.'));
      return ListView(children: [for (final row in snapshot.data!) ListTile(leading: const Icon(Icons.attach_file),
        title: Text(row['name'] as String), subtitle: Text('${row['size_bytes']} bytes'), trailing: const Icon(Icons.chevron_right),
        onTap: () => open(row['id'] as int))]);
    }));
}
class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.bytes, required this.name, required this.mime});
  final Uint8List bytes; final String name, mime;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(name), actions: [
    IconButton(tooltip: 'Download / Share', icon: const Icon(Icons.ios_share), onPressed: () async {
      try {await shareFile(context, bytes, name, mime);}
      catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file sharing.')));}
    }),
  ]), body: mime == 'application/pdf' ? PdfPreview(build: (_) async => bytes, canChangePageFormat: false,
    canChangeOrientation: false, allowSharing: false) : InteractiveViewer(child: Center(child: Image.memory(bytes, cacheWidth: 1600,
      errorBuilder: (context, error, stack) => const Text('Image could not be displayed.')))));
}
