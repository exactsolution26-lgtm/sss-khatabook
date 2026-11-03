import '../db_helper.dart';
import '../../models/expense_model.dart';

class ExpenseTable {
  static Future<void> insertExpense(ExpenseModel expense) async {
    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('Expense amount must be positive and finite');
    }
    final db = await DBHelper.database;
    await db.insert('expenses', expense.toMap());
  }
}
