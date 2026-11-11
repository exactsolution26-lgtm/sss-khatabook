import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import 'backup_vault.dart';
import '../workspace/workspace_schema.dart';
import '../workspace/workspace_store.dart';
import '../entries/party_snapshot.dart';
import '../entries/attachments.dart';
import '../entries/record_recovery.dart';
import '../followups/reminder_notifications.dart';

class BackupCipher {
  static const iterations = 600000;
  static final _aes = AesGcm.with256bits();
  static List<int> randomBytes(int length) => List.generate(length, (_) => Random.secure().nextInt(256));

  static Future<String> encrypt(Map<String, dynamic> data, String password) async {
    if (password.length < 12 || password.length > 1024) {
      throw ArgumentError('Use a backup passphrase with 12–1024 characters');
    }
    final plain = utf8.encode(jsonEncode(data));
    if (plain.length > 50000000) throw const FormatException('Backup exceeds 50 MB record limit');
    final salt = randomBytes(16);
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final box = await _aes.encrypt(plain, secretKey: key,
      nonce: _aes.newNonce(), aad: utf8.encode('sss-khatabook:backup:1'));
    return jsonEncode({'format': 'sss-khatabook-encrypted', 'version': 1,
      'iterations': iterations, 'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce), 'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes)});
  }

  static Future<Map<String, dynamic>> decrypt(String input, String password) async {
    if (input.length > 75000000 || password.length > 1024) throw const FormatException('Backup too large');
    final envelope = jsonDecode(input) as Map<String, dynamic>;
    if (envelope['format'] != 'sss-khatabook-encrypted' || envelope['version'] != 1 ||
        envelope['iterations'] != iterations) throw const FormatException('Unsupported backup');
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final mac = base64Decode(envelope['mac'] as String);
    if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Invalid backup encryption');
    }
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final bytes = await _aes.decrypt(SecretBox(base64Decode(envelope['ciphertext'] as String),
      nonce: nonce, mac: Mac(mac)), secretKey: key, aad: utf8.encode('sss-khatabook:backup:1'));
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

class BackupService {
  BackupService({Future<void> Function(int)? cancelReminder}) : cancelReminder = cancelReminder ?? ReminderNotifications.cancel;
  final Future<void> Function(int) cancelReminder;
  static const tableNames = ['accounts', 'income', 'expenses', 'work', 'entry_categories', 'app_audit', 'attachments', 'obligations', 'payment_allocations', 'follow_ups', 'recycled_entries', ...WorkspaceSchema.tables];

  Future<Map<String, dynamic>> snapshot() async {
    final db = await DBHelper.database;
    return db.transaction(_snapshot);
  }

  // The portable row format stays at schema 11. SQLite schemas 12 and 13 change indexes and triggers only.
  Future<Map<String, dynamic>> _snapshot(Transaction txn) async => {
    'format': 'sss-khatabook-records', 'version': 1, 'schema': 11,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'tables': {for (final table in tableNames) table: await txn.query(table, orderBy: 'rowid')},
  };

  Map<String, List<Map<String, Object?>>> validateShape(Map<String, dynamic> data) {
    if (data['format'] != 'sss-khatabook-records' || data['version'] != 1 || ![6, 7, 8, 9, 10, 11].contains(data['schema'])) {
      throw const FormatException('Unsupported record format');
    }
    DateTime.parse(data['created_at'] as String);
    final source = Map<String, dynamic>.from(data['tables'] as Map);
    if (data['schema'] == 6 && !source.containsKey('attachments')) source['attachments'] = [];
    if ((data['schema'] as int) < 8) {source['obligations'] = []; source['payment_allocations'] = []; source['follow_ups'] = [];}
    if ((data['schema'] as int) < 9) source['recycled_entries'] = [];
    if ((data['schema'] as int) < 10) {for(final table in WorkspaceSchema.tables) {source[table]=[];}}
    if (source.length != tableNames.length || !tableNames.every(source.containsKey)) {
      throw const FormatException('Incomplete backup');
    }
    final result = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final table in tableNames) {
      final rows = source[table] as List;
      if(table=='message_templates' && rows.length>50)throw const FormatException('Too many message templates');
      count += rows.length;
      if (count > 100000) throw const FormatException('Backup row limit exceeded');
      result[table] = rows.map((value) {
        final row = Map<String, Object?>.from(value as Map);
        if (['accounts', 'income', 'expenses', 'work', 'attachments', 'obligations', 'payment_allocations', 'follow_ups', 'recycled_entries'].contains(table) &&
            (row['id'] is! int || (row['id'] as int) <= 0)) {
          throw const FormatException('Invalid original record identity');
        }
        for (final entry in row.entries) {
          final item = entry.value;
          if (item != null && item is! String && item is! num) {
            throw const FormatException('Invalid backup value');
          }
          if (item is num && !item.isFinite) throw const FormatException('Non-finite backup amount');
          final maximum = table == 'attachments' && entry.key == 'content_base64' ? 6990520 : table == 'recycled_entries' && entry.key == 'payload' ? 16000000 : 1000000;
          if (item is String && item.length > maximum) throw const FormatException('Backup value too large');
          if (item != null && entry.key.endsWith('_at') &&
              (item is! String || DateTime.tryParse(item) == null)) throw const FormatException('Invalid stored timestamp');
        }
        if(table=='business_profile') {
          if(row['id']!=1) throw const FormatException('Invalid business profile identity');
          WorkspaceStore.profileValues(name:row['name'] as String,phone:row['phone'] as String,
            email:row['email'] as String,address:row['address'] as String);
        }
        if(table=='contact_directory') {
          final contact=PartySnapshot.optional(row['name'] as String,row['phone'] as String);
          if(row['id'] is! int || (row['id'] as int)<=0 || contact==null || contact.phone!=row['phone']) throw const FormatException('Invalid contact');
        }
        if(table=='message_templates') {
          WorkspaceStore.validateTemplate(row['title'] as String,row['body'] as String);
          if(row['id'] is! int || (row['id'] as int)<=0) throw const FormatException('Invalid template identity');
        }
        if(table=='import_records' &&
          (row['source_key'] is! String || !RegExp(r'^(hash:[a-f0-9]{64}|external:[A-Za-z0-9_.:-]{1,120})$').hasMatch(row['source_key'] as String) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['content_hash'] as String) ||
          !['income','expense'].contains(row['kind']) || row['record_id'] is! int || (row['record_id'] as int)<=0)) {
          throw const FormatException('Invalid import identity');
        }
        if (table == 'income' || table == 'expenses') {
          final amount = row['amount'];
          if (amount is! num || amount <= 0 || amount > 90000000000000) {
            throw const FormatException('Invalid financial amount');
          }
          if (table == 'income' && row['account_id'] == null) {
            throw const FormatException('Income account missing');
          }
          if (row['date'] is! String || DateTime.tryParse(row['date'] as String) == null) {
            throw const FormatException('Invalid financial date');
          }
        }
        if (table == 'accounts' &&
            (row['name'] is! String || (row['name'] as String).trim().isEmpty ||
            (row['name'] as String).length > 120 || row['opening_balance'] is! num ||
            (row['opening_balance'] as num) < 0)) throw const FormatException('Invalid account');
        return row;
      }).toList();
    }
    return result;
  }

  /// All schema constraints and links are tested away from the live database.
  Future<void> validate(Map<String, dynamic> data) async => _validateTables(validateShape(data));

  Future<void> _validateTables(Map<String, List<Map<String, Object?>>> tables) async {
    final attachmentTotals = <String, (int, int)>{};
    for (final row in tables['attachments']!) {
      final bytes = base64Decode(row['content_base64'] as String);
      final inspected = await PendingAttachment.inspect(row['name'] as String, bytes);
      if (inspected.name != row['name'] || inspected.mime != row['mime_type'] || bytes.length != row['size_bytes']) {
        throw const FormatException('Attachment metadata mismatch');
      }
      final group = '${row['income_id'] == null ? 'expense' : 'income'}:${row['income_id'] ?? row['expense_id']}';
      final previous = attachmentTotals[group] ?? (0, 0);
      final next = (previous.$1 + 1, previous.$2 + bytes.length);
      if (next.$1 > 5 || next.$2 > 10 * 1024 * 1024) throw const FormatException('Attachment limit exceeded');
      attachmentTotals[group] = next;
    }
    // A crash during validation must not leave an unencrypted staging file.
    final temporary = await DBHelper.openAt(inMemoryDatabasePath);
    try {
      // Reject unknown columns before inserting; bound data never becomes SQL.
      for (final table in tableNames) {
        final columns = (await temporary.rawQuery('PRAGMA table_info($table)')).map((r) => r['name']).toSet();
        if (tables[table]!.any((r) => !r.keys.every(columns.contains))) {
          throw const FormatException('Unknown backup fields');
        }
      }
      for(final row in tables['recycled_entries']!) {await RecordRecovery.validatePayload(temporary,row);}
      await DBHelper.replaceSnapshot(temporary, tables);
      if ((await temporary.rawQuery('PRAGMA integrity_check')).single.values.single != 'ok') {
        throw const FormatException('Backup integrity failed');
      }
    } finally {
      await temporary.close();
    }
  }

  Future<void> restore(Map<String, dynamic> data, {required String recoveryPassword}) async {
    final tables = validateShape(data);
    await _validateTables(tables);
    final reminders = <int>[];
    await DBHelper.replaceSnapshot(await DBHelper.database, tables, beforeReplace: (txn) async {
      // Keep ledger writes serialized until the exact pre-restore state is safe in the vault.
      final current = await _snapshot(txn);
      final recovery = await BackupCipher.encrypt(current, recoveryPassword);
      await BackupVault.put(recovery, purpose: 'recovery');
      for (final row in ((current['tables'] as Map)['follow_ups'] as List)) {
        if (row['notification_scheduled'] == 1) reminders.add(row['id'] as int);
      }
    });
    for (final id in reminders) {
      try {await cancelReminder(id);} catch (_) { /* Restored in-app reminders remain available. */ }
    }
  }
}
