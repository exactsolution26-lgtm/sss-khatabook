import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as paths;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';

class BackupCipher {
  static const iterations = 600000;
  static final _aes = AesGcm.with256bits();
  static List<int> randomBytes(int length) => List.generate(length, (_) => Random.secure().nextInt(256));

  static Future<String> encrypt(Map<String, dynamic> data, String password) async {
    if (password.length < 12 || password.length > 1024) {
      throw ArgumentError('Use a backup passphrase with 12–1024 characters');
    }
    final salt = randomBytes(16);
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final box = await _aes.encrypt(utf8.encode(jsonEncode(data)), secretKey: key,
      nonce: _aes.newNonce(), aad: utf8.encode('sss-khatabook:backup:1'));
    return jsonEncode({'format': 'sss-khatabook-encrypted', 'version': 1,
      'iterations': iterations, 'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce), 'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes)});
  }

  static Future<Map<String, dynamic>> decrypt(String input, String password) async {
    if (input.length > 30000000 || password.length > 1024) throw const FormatException('Backup too large');
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
  static const tableNames = ['accounts', 'income', 'expenses', 'work', 'entry_categories', 'app_audit'];

  Future<Map<String, dynamic>> snapshot() async {
    final db = await DBHelper.database;
    return db.transaction((txn) async => {
      'format': 'sss-khatabook-records', 'version': 1, 'schema': 6,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tables': {for (final table in tableNames) table: await txn.query(table, orderBy: 'rowid')},
    });
  }

  Map<String, List<Map<String, Object?>>> validateShape(Map<String, dynamic> data) {
    if (data['format'] != 'sss-khatabook-records' || data['version'] != 1 || data['schema'] != 6) {
      throw const FormatException('Unsupported record format');
    }
    DateTime.parse(data['created_at'] as String);
    final source = data['tables'] as Map<String, dynamic>;
    if (source.length != tableNames.length || !tableNames.every(source.containsKey)) {
      throw const FormatException('Incomplete backup');
    }
    final result = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final table in tableNames) {
      final rows = source[table] as List;
      count += rows.length;
      if (count > 100000) throw const FormatException('Backup row limit exceeded');
      result[table] = rows.map((value) {
        final row = Map<String, Object?>.from(value as Map);
        if (['accounts', 'income', 'expenses', 'work'].contains(table) &&
            (row['id'] is! int || (row['id'] as int) <= 0)) {
          throw const FormatException('Invalid original record identity');
        }
        for (final item in row.values) {
          if (item != null && item is! String && item is! num) {
            throw const FormatException('Invalid backup value');
          }
          if (item is num && !item.isFinite) throw const FormatException('Non-finite backup amount');
          if (item is String && item.length > 1000000) throw const FormatException('Backup value too large');
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
  Future<void> validate(Map<String, dynamic> data) async {
    final tables = validateShape(data);
    final path = paths.join(await getDatabasesPath(), 'sss-validate-${base64UrlEncode(BackupCipher.randomBytes(18))}.db');
    final temporary = await DBHelper.openAt(path);
    try {
      // Reject unknown columns before inserting; bound data never becomes SQL.
      for (final table in tableNames) {
        final columns = (await temporary.rawQuery('PRAGMA table_info($table)')).map((r) => r['name']).toSet();
        if (tables[table]!.any((r) => !r.keys.every(columns.contains))) {
          throw const FormatException('Unknown backup fields');
        }
      }
      await DBHelper.replaceSnapshot(temporary, tables);
      if ((await temporary.rawQuery('PRAGMA integrity_check')).single.values.single != 'ok') {
        throw const FormatException('Backup integrity failed');
      }
    } finally {
      await temporary.close();
      await databaseFactory.deleteDatabase(path);
    }
  }

  Future<void> restore(Map<String, dynamic> data, {required String recoveryPassword}) async {
    await validate(data);
    // A recoverable encrypted copy must persist before any existing row changes.
    final recovery = await BackupCipher.encrypt(await snapshot(), recoveryPassword);
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString('sss_pre_restore_recovery_v1', recovery)) {
      throw StateError('Could not retain current records before restore');
    }
    await DBHelper.replaceSnapshot(await DBHelper.database, validateShape(data));
  }
}
