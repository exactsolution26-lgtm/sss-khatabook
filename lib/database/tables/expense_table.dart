import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../../models/expense_model.dart';

class ExpenseTable {
  static const String tableName = 'expenses';
  static const String id = 'id';
  static const String accountId = 'account_id';
  static const String amount = 'amount';
  static const String mode = 'mode';
  static const String category = 'category';
  static const String note = 'note';
  static const String date = 'date';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $id INTEGER PRIMARY KEY AUTOINCREMENT,
      $accountId INTEGER,
      $amount REAL NOT NULL,
      $mode TEXT,
      $category TEXT,
      $note TEXT,
      $date TEXT NOT NULL
    )
  ''';

  static Future<int> insertExpense(ExpenseModel expense) async {
    final db = await DBHelper.instance.database;
    return await db.insert(
      tableName,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ExpenseModel>> getAll() async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(tableName, orderBy: '$date DESC');
    return maps.map((map) => ExpenseModel.fromMap(map)).toList();
  }

  static Future<double> getTotalExpensesByAccount(int accountId) async {
    final db = await DBHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM($amount) as total FROM $tableName WHERE $accountId = ?',
      [accountId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<double> getTotalExpenses() async {
    final db = await DBHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM($amount) as total FROM $tableName',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
