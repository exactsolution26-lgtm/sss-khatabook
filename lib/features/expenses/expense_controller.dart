import '../../database/db_helper.dart';
import '../../database/tables/expense_table.dart';
import '../../models/expense_model.dart';

class ExpenseController {
  Future<void> saveExpense(ExpenseModel expense) =>
      ExpenseTable.insertExpense(expense);

  Future<double> getTotalExpensesByAccount(int accountId) async {
    final db = await DBHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM expenses WHERE account_id = ?',
      [accountId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
