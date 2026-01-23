import '../../database/tables/expense_table.dart';
import '../../models/expense_model.dart';

class ExpenseController {
  Future<void> saveExpense(ExpenseModel expense) async {
    await ExpenseTable.insertExpense(expense);
  }
}
