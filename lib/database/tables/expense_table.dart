import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../../models/expense_model.dart';

class ExpenseTable {
  static Future<void> insertExpense(ExpenseModel expense) async {
    final db = await DBHelper.database;

    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
