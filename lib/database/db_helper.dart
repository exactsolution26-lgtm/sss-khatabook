import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_khata.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {

        // Accounts table (already added)
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY,
            cash_balance REAL,
            bank_balance REAL
          )
        ''');

        // Expenses table (NEW – Step 6)
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL,
            mode TEXT,
            category TEXT,
            note TEXT,
            date TEXT
          )
        ''');
      },
    );
  }
}
