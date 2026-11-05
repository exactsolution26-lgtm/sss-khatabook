import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'tables/income_table.dart';
import '../features/workspace/workspace_schema.dart';
import '../features/entries/record_recovery.dart';
import 'tables/work_table.dart';
import 'recovery_schema.dart';
import '../features/entries/attachments.dart';
import '../features/dues/dues_schema.dart';
import '../features/followups/followup_schema.dart';

class DBHelper {
  static Database? _db;
  static Future<Database>? _opening;
  static Future<Database> get database =>
      _db != null ? Future.value(_db!) : _opening ??= _open();

  static Future<Database> _open() async {
    try {
      return _db = await _initDB();
    } finally {
      _opening = null;
    }
  }

  /// Tests use the same schema/migrations with a separate database file.
  static Future<Database> openAt(String path, {DatabaseFactory? factory}) =>
      (factory ?? databaseFactory).openDatabase(path, options: options);

  static Future<void> close() async {
    if (_opening != null) await _opening;
    await _db?.close();
    _db = null;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'offline_khata.db');
    return openAt(path);
  }

  static OpenDatabaseOptions get options => OpenDatabaseOptions(
    version: 11,
    onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await db.execute('''CREATE TABLE accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          opening_balance REAL NOT NULL DEFAULT 0,
          cash_balance REAL NOT NULL DEFAULT 0,
          bank_balance REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          opening_balance_saved_at TEXT, archived_at TEXT
        )''');
      await db.execute('''CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER,
          amount REAL NOT NULL CHECK(amount > 0),
          mode TEXT, category TEXT, note TEXT, date TEXT NOT NULL,
          created_at TEXT, updated_at TEXT, contact_name TEXT, contact_phone TEXT,
          FOREIGN KEY(account_id) REFERENCES accounts(id)
        )''');
      await db.execute(IncomeTable.createTable);
      await db.execute(WorkTable.createTable);
      await _createCategoryTable(db);
      await _installIntegrityGuards(db);
      await RecoverySchema.install(db);
      await AttachmentStore.install(db);
      await DuesSchema.install(db);
      await FollowupSchema.install(db);
      await RecordRecovery.install(db);
      await WorkspaceSchema.install(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if(oldVersion<11) await db.execute('ALTER TABLE accounts ADD COLUMN archived_at TEXT');
      if (oldVersion < 2) {
        final columns = await db.rawQuery('PRAGMA table_info(accounts)');
        final names = columns.map((c) => c['name']).toSet();
        if (!names.contains('name')) {
          await db.execute(
            "ALTER TABLE accounts ADD COLUMN name TEXT NOT NULL DEFAULT 'Main Account'",
          );
        }
        if (!names.contains('opening_balance')) {
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE accounts SET opening_balance = COALESCE(cash_balance,0) + COALESCE(bank_balance,0)',
          );
        }
        if (!names.contains('created_at')) {
          await db.execute(
            "ALTER TABLE accounts ADD COLUMN created_at TEXT NOT NULL DEFAULT '1970-01-01 00:00:00'",
          );
        }
        final expenseColumns = await db.rawQuery('PRAGMA table_info(expenses)');
        if (!expenseColumns.any((c) => c['name'] == 'account_id')) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN account_id INTEGER REFERENCES accounts(id)',
          );
        }
        await db.execute(IncomeTable.createTable);
        await db.execute(WorkTable.createTable);
      }
      if (oldVersion < 3) await _installIntegrityGuards(db);
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE accounts ADD COLUMN opening_balance_saved_at TEXT');
      }
      if (oldVersion < 5) {
        await _createCategoryTable(db);
        for (final table in ['income', 'expenses']) {
          final existing = (await db.rawQuery('PRAGMA table_info($table)'))
              .map((row) => row['name']).toSet();
          final columns = table == 'income'
              ? ['updated_at', 'contact_name', 'contact_phone', 'category', 'mode']
              : ['created_at', 'updated_at', 'contact_name', 'contact_phone'];
          for (final column in columns) {
            if (!existing.contains(column)) {
              await db.execute('ALTER TABLE $table ADD COLUMN $column TEXT');
            }
          }
        }
      }
      if (oldVersion < 6) await RecoverySchema.install(db);
      if (oldVersion < 7) await AttachmentStore.install(db);
      if (oldVersion < 8) {await DuesSchema.install(db); await FollowupSchema.install(db);}
      if (oldVersion < 9) await RecordRecovery.install(db);
      if (oldVersion < 10) await WorkspaceSchema.install(db);
      if (oldVersion < 11) await _installIntegrityGuards(db);
    },
  );

  /// Restore is one transaction. Only the recovery service calls this after
  /// validating a complete snapshot in a disposable database.
  static Future<void> replaceSnapshot(Database db,
      Map<String, List<Map<String, Object?>>> tables) => db.transaction((txn) async {
    // Old unassigned expenses must survive recovery. Temporarily drop only
    // write guards inside this exclusive transaction; always reinstall them.
    for (final table in ['income', 'expenses']) {
      for (final action in ['insert', 'update']) {
        await txn.execute('DROP TRIGGER IF EXISTS ${table}_${action}_guard');
      }
    }
    await txn.execute('DROP TRIGGER IF EXISTS account_opening_lock');
    await txn.execute('DROP TRIGGER IF EXISTS payment_no_delete');
    for (final table in [...WorkspaceSchema.tables, 'recycled_entries', 'attachments', 'follow_ups', 'payment_allocations', 'obligations', 'income', 'expenses', 'work', 'entry_categories']) {
      await txn.delete(table);
    }
    await txn.delete('accounts');
    for (final table in ['accounts', 'income', 'expenses', 'work', 'entry_categories', 'obligations', 'payment_allocations', 'attachments', 'follow_ups', 'recycled_entries', ...WorkspaceSchema.tables]) {
      for (final row in tables[table]!) {
        await txn.insert(table, table == 'follow_ups' ? {...row, 'notification_scheduled': 0} : row);
      }
    }
    // A restore must not reuse the identity of an entry retained in the recycle bin.
    for(final kind in ['income','expenses']) {
      final maximum=(await txn.rawQuery('SELECT COALESCE(MAX(record_id),0) AS value FROM recycled_entries WHERE kind=?',[kind])).single['value'] as int;
      await txn.rawUpdate('UPDATE sqlite_sequence SET seq=MAX(seq,?) WHERE name=?',[maximum,kind]);
      if((await txn.rawQuery('SELECT name FROM sqlite_sequence WHERE name=?',[kind])).isEmpty && maximum>0) {
        await txn.rawInsert('INSERT INTO sqlite_sequence(name,seq) VALUES(?,?)',[kind,maximum]);
      }
    }
    for (final row in tables['app_audit']!) {
      await txn.insert('app_audit', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('Backup contains invalid account links');
    }
    await _installIntegrityGuards(txn);
    await DuesSchema.install(txn);
    await txn.insert('app_audit', {'entity': 'database', 'operation': 'restore'});
  });
  static Future<void> _createCategoryTable(DatabaseExecutor db) => db.execute(
    "CREATE TABLE IF NOT EXISTS entry_categories (kind TEXT NOT NULL CHECK(kind IN ('income','expense')), name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60), created_at TEXT NOT NULL, UNIQUE(kind,name COLLATE NOCASE))",
  );

  static Future<void> _installIntegrityGuards(DatabaseExecutor db) async {
    await db.execute('DROP TRIGGER IF EXISTS account_opening_lock');
    for(final table in ['income','expenses']) {for(final action in ['insert','update']) {
      await db.execute('DROP TRIGGER IF EXISTS ${table}_${action}_guard');
    }}
    await db.execute(
      '''CREATE TRIGGER account_opening_lock BEFORE UPDATE ON accounts
      WHEN (NEW.opening_balance IS NOT OLD.opening_balance
        OR NEW.cash_balance IS NOT OLD.cash_balance OR NEW.bank_balance IS NOT OLD.bank_balance)
        AND (EXISTS(SELECT 1 FROM income WHERE account_id = OLD.id)
          OR EXISTS(SELECT 1 FROM expenses WHERE account_id = OLD.id))
      BEGIN SELECT RAISE(ABORT, 'Opening balance locked after first transaction'); END''',
    );
    for (final table in ['income', 'expenses']) {
      for (final operation in ['INSERT', 'UPDATE']) {
        await db.execute(
          '''CREATE TRIGGER ${table}_${operation.toLowerCase()}_guard
          BEFORE $operation ON $table
          WHEN NEW.account_id IS NULL OR NEW.amount IS NULL OR NEW.amount <= 0
            OR NEW.amount > 90000000000000
            OR EXISTS(SELECT 1 FROM accounts a WHERE a.id=NEW.account_id AND a.archived_at IS NOT NULL)
          BEGIN SELECT RAISE(ABORT, 'Invalid financial record'); END''',
        );
      }
    }
  }
}

// Compatibility for existing controllers; prefer DBHelper.database in new code.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();
  Future<Database> get database => DBHelper.database;
}
