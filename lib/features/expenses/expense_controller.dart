import '../../database/db_helper.dart';
import '../../database/tables/expense_table.dart';
import '../../models/expense_model.dart';
import '../entries/attachments.dart';

class ExpenseController {
  Future<ExpenseModel> saveExpense(ExpenseModel expense, {List<PendingAttachment> attachments = const []}) async {
    final id = await ExpenseTable.insertExpense(expense, attachments: attachments);
    final db = await DBHelper.database;
    return ExpenseModel.fromMap((await db.query('expenses', where: 'id = ?', whereArgs: [id])).single);
  }

  Future<double> getTotalExpensesByAccount(int accountId) async {
    final db = await DBHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM expenses WHERE account_id = ?',
      [accountId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
