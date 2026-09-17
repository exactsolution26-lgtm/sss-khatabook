import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../../models/income_model.dart';

class IncomeTable {
  static const String tableName = 'income';

  static const String id = 'id';
  static const String accountId = 'account_id';
  static const String amount = 'amount';
  static const String description = 'description';
  static const String date = 'date';
  static const String createdAt = 'created_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $id INTEGER PRIMARY KEY AUTOINCREMENT,
      $accountId INTEGER NOT NULL,
      $amount REAL NOT NULL,
      $description TEXT,
      $date TEXT NOT NULL,
      $createdAt TEXT NOT NULL,
      FOREIGN KEY ($accountId) REFERENCES accounts($id)
    )
  ''';

  static Future<int> insert(IncomeModel income) async {
    final db = await DBHelper.instance.database;
    return await db.insert(tableName, income.toMap());
  }

  static Future<List<IncomeModel>> getAll() async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(tableName, orderBy: '$date DESC');
    return maps.map((map) => IncomeModel.fromMap(map)).toList();
  }

  static Future<double> getTotalIncome() async {
    final db = await DBHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM($amount) as total FROM $tableName',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
