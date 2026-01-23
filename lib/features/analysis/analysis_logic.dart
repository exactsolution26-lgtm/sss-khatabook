import '../../features/accounts/account_controller.dart';
import '../../features/expenses/expense_controller.dart';
import '../../features/income/income_controller.dart';
import '../../models/account_model.dart';

class AnalysisLogic {
  final AccountController _accountController = AccountController();
  final ExpenseController _expenseController = ExpenseController();
  final IncomeController _incomeController = IncomeController();

  Future<Map<String, dynamic>> getAnalysisData() async {
    final accounts = await _accountController.getAllAccounts();
    final analysisData = <String, dynamic>{};

    double totalIncome = 0;
    double totalExpense = 0;
    double totalBalance = 0;

    for (var account in accounts) {
      final income = await _incomeController.getTotalIncomeByAccount(account.id!);
      final expense = await _expenseController.getTotalExpensesByAccount(account.id!);
      final balance = account.openingBalance + income - expense;

      totalIncome += income;
      totalExpense += expense;
      totalBalance += balance;
    }

    analysisData['totalIncome'] = totalIncome;
    analysisData['totalExpense'] = totalExpense;
    analysisData['totalBalance'] = totalBalance;
    analysisData['accounts'] = accounts;

    return analysisData;
  }

  Future<List<Map<String, dynamic>>> getAccountDetails() async {
    final accounts = await _accountController.getAllAccounts();
    final details = <Map<String, dynamic>>[];

    for (var account in accounts) {
      final income = await _incomeController.getTotalIncomeByAccount(account.id!);
      final expense = await _expenseController.getTotalExpensesByAccount(account.id!);
      final balance = account.openingBalance + income - expense;

      details.add({
        'account': account,
        'openingBalance': account.openingBalance,
        'income': income,
        'expense': expense,
        'balance': balance,
      });
    }

    return details;
  }
}
