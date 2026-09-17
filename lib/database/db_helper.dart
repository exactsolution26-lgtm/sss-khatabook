import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables/account_table.dart';
import 'tables/income_table.dart';
import 'tables/expense_table.dart';
import 'tables/work_table.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _db;

  DBHelper._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_khata.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(AccountTable.createTable);
        await db.execute(IncomeTable.createTable);
        await db.execute(ExpenseTable.createTable);
        await db.execute(WorkTable.createTable);
      },
    );
  }
}
