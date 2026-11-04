import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:sqflite/sqflite.dart';

class PendingAttachment {
  PendingAttachment._(this.name, this.mime, this.bytes);
  final String name, mime;
  final Uint8List bytes;
  static Future<PendingAttachment> inspect(String fileName, Uint8List input) async {
    if (input.isEmpty || input.length > 5 * 1024 * 1024) throw const FormatException('Each attachment must be at most 5 MB');
    final pdf = input.length >= 5 && ascii.decode(input.take(5).toList(), allowInvalid: true) == '%PDF-';
    final png = input.length >= 8 && base64Encode(input.sublist(0, 8)) == 'iVBORw0KGgo=';
    final jpg = input.length >= 3 && input[0] == 255 && input[1] == 216 && input[2] == 255;
    if (!pdf && !png && !jpg) throw const FormatException('Choose a PDF, JPG or PNG file');
    if (!pdf) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(input);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 12000 || descriptor.height > 12000 || descriptor.width * descriptor.height > 40000000) {
            throw const FormatException('Image dimensions too large');
          }
        } finally {descriptor.dispose();}
      } finally {buffer.dispose();}
    }
    var name = fileName.replaceAll('\\', '/').split('/').last.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    if (name.isEmpty) name = 'attachment';
    if (name.length > 100) name = name.substring(0, 100);
    final extension = pdf ? 'pdf' : png ? 'png' : 'jpg';
    return PendingAttachment._('$name.$extension', pdf ? 'application/pdf' : png ? 'image/png' : 'image/jpeg', Uint8List.fromList(input));
  }
}

class AttachmentStore {
  static Future<void> install(DatabaseExecutor db) => db.execute('''CREATE TABLE IF NOT EXISTS attachments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    income_id INTEGER REFERENCES income(id) ON DELETE CASCADE,
    expense_id INTEGER REFERENCES expenses(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
    mime_type TEXT NOT NULL CHECK(mime_type IN ('application/pdf','image/png','image/jpg','image/jpeg')),
    size_bytes INTEGER NOT NULL CHECK(size_bytes BETWEEN 1 AND 5242880),
    content_base64 TEXT NOT NULL CHECK(length(content_base64) <= 6990520),
    created_at TEXT NOT NULL,
    CHECK((income_id IS NULL) != (expense_id IS NULL))
  )''');
  static Future<void> insertBatch(DatabaseExecutor db, List<PendingAttachment> files, {int? incomeId, int? expenseId}) async {
    if (files.length > 5 || files.fold<int>(0, (sum, f) => sum + f.bytes.length) > 10 * 1024 * 1024) {
      throw const FormatException('At most 5 attachments and 10 MB per entry');
    }
    for (final file in files) {
      await db.insert('attachments', {'income_id': incomeId, 'expense_id': expenseId,
        'name': file.name, 'mime_type': file.mime, 'size_bytes': file.bytes.length,
        'content_base64': base64Encode(file.bytes), 'created_at': DateTime.now().toUtc().toIso8601String()});
    }
  }
}
