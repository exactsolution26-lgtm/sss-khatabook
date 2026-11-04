import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

/// Separate database: a ledger rollback/corruption cannot overwrite its recovery
/// copies. Only authenticated ciphertext is supplied by BackupService.
class BackupVault {
  static Future<T> _use<T>(Future<T> Function(Database) operation) async {
    final db = await databaseFactory.openDatabase(paths.join(await getDatabasesPath(), 'sss_backup_vault.db'),
      options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: (db, _) => db.execute(
        'CREATE TABLE snapshots(id INTEGER PRIMARY KEY AUTOINCREMENT,purpose TEXT NOT NULL,encrypted TEXT NOT NULL,created_at TEXT NOT NULL)')));
    try {return await operation(db);} finally {await db.close();}
  }
  static Future<void> put(String encrypted, {String purpose = 'automatic'}) => _use((db) => db.transaction((txn) async {
    await txn.insert('snapshots', {'purpose': purpose, 'encrypted': encrypted,
      'created_at': DateTime.now().toUtc().toIso8601String()});
    await txn.rawDelete('DELETE FROM snapshots WHERE purpose = ? AND id NOT IN (SELECT id FROM snapshots WHERE purpose = ? ORDER BY id DESC LIMIT ?)',
      [purpose, purpose, purpose == 'automatic' ? 7 : 1]);
  }));
  static Future<List<Map<String, Object?>>> list({String purpose = 'automatic'}) => _use((db) => db.query(
    'snapshots', columns: ['id', 'created_at'], where: 'purpose = ?', whereArgs: [purpose], orderBy: 'id DESC'));
  static Future<String> read(int id) => _use((db) async {
    final rows = await db.query('snapshots', columns: ['encrypted'], where: 'id = ?', whereArgs: [id]);
    if (rows.length != 1) throw StateError('Checkpoint missing');
    return rows.single['encrypted'] as String;
  });
}
