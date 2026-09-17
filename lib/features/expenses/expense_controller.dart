import '../../database/tables/expense_table.dart';
import '../../models/expense_model.dart';

class ExpenseController {
  Future<int> saveExpense(ExpenseModel expense) async {
    return await ExpenseTable.insertExpense(expense);
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    return await ExpenseTable.getAll();
  }

  Future<double> getTotalExpensesByAccount(int accountId) async {
    return await ExpenseTable.getTotalExpensesByAccount(accountId);
  }

  Future<double> getTotalExpenses() async {
    return await ExpenseTable.getTotalExpenses();
  }
}
