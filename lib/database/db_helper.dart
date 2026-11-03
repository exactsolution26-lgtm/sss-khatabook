import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables/income_table.dart';
import 'tables/work_table.dart';

class DBHelper {
  static Database? _db;
  static Future<Database> get database async => _db ??= await _initDB();

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'offline_khata.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          opening_balance REAL NOT NULL DEFAULT 0,
          cash_balance REAL NOT NULL DEFAULT 0,
          bank_balance REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(accounts)');
          final names = columns.map((c) => c['name']).toSet();
          if (!names.contains('name')) {
            await db.execute("ALTER TABLE accounts ADD COLUMN name TEXT NOT NULL DEFAULT 'Main Account'");
          }
          if (!names.contains('opening_balance')) {
            await db.execute('ALTER TABLE accounts ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0');
            await db.execute('UPDATE accounts SET opening_balance = COALESCE(cash_balance,0) + COALESCE(bank_balance,0)');
          }
          if (!names.contains('created_at')) {
            await db.execute("ALTER TABLE accounts ADD COLUMN created_at TEXT NOT NULL DEFAULT '1970-01-01 00:00:00'");
          }
          final expenseColumns = await db.rawQuery('PRAGMA table_info(expenses)');
          if (!expenseColumns.any((c) => c['name'] == 'account_id')) {
            await db.execute('ALTER TABLE expenses ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
          }
          await db.execute(IncomeTable.createTable);
          await db.execute(WorkTable.createTable);
        }
      },
    );
  }
}

// Compatibility for existing controllers; prefer DBHelper.database in new code.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();
  Future<Database> get database => DBHelper.database;
}
