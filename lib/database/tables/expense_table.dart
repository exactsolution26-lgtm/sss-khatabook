import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../../models/expense_model.dart';

class ExpenseTable {
  static Future<void> insertExpense(ExpenseModel expense) async {
    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }
    if (expense.category.trim().isEmpty) {
      throw ArgumentError('Expense category is required.');
    }
    if (expense.mode != 'cash' && expense.mode != 'online') {
      throw ArgumentError('Invalid payment mode.');
    }

    final db = await DBHelper.database;
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
