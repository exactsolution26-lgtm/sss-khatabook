import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'tables/income_table.dart';
import 'tables/work_table.dart';

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
    version: 4,
    onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await db.execute('''CREATE TABLE accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          opening_balance REAL NOT NULL DEFAULT 0,
          cash_balance REAL NOT NULL DEFAULT 0,
          bank_balance REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          opening_balance_saved_at TEXT
        )''');
      await db.execute('''CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER,
          amount REAL NOT NULL CHECK(amount > 0),
          mode TEXT, category TEXT, note TEXT, date TEXT NOT NULL,
          FOREIGN KEY(account_id) REFERENCES accounts(id)
        )''');
      await db.execute(IncomeTable.createTable);
      await db.execute(WorkTable.createTable);
      await _installIntegrityGuards(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
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
    },
  );
  static Future<void> _installIntegrityGuards(DatabaseExecutor db) async {
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
