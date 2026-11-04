import '../../database/db_helper.dart';
import '../../models/account_model.dart';

class AnalysisLogic {
  /// One SQLite snapshot keeps totals and account details mutually consistent.
  Future<Map<String, dynamic>> getAnalysisData() async {
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery('''SELECT a.*,
        COALESCE(i.total,0) AS total_income, COALESCE(e.total,0) AS total_expense
        FROM accounts a
        LEFT JOIN (SELECT account_id,SUM(amount) AS total FROM income GROUP BY account_id) i ON i.account_id=a.id
        LEFT JOIN (SELECT account_id,SUM(amount) AS total FROM expenses GROUP BY account_id) e ON e.account_id=a.id
        ORDER BY a.id''');
      final legacy = await txn.rawQuery(
        'SELECT COUNT(*) AS count,COALESCE(SUM(amount),0) AS total FROM expenses WHERE account_id IS NULL',
      );
      final unassigned = (legacy.single['total'] as num).toDouble();
      final recent = await txn.rawQuery('''
        SELECT * FROM (SELECT id, account_id, amount, description AS note, date, 'income' AS kind
        FROM income
        UNION ALL
        SELECT id, account_id, amount, note, date, 'expense' AS kind FROM expenses)
        ORDER BY datetime(date) DESC, id DESC LIMIT 12
      ''');
      var totalIncome = 0.0;
      var totalExpense = unassigned;
      var totalBalance = -unassigned;
      final details = <Map<String, dynamic>>[];
      final accounts = <AccountModel>[];
      for (final row in rows) {
        final account = AccountModel.fromMap(row);
        accounts.add(account);
        final income = (row['total_income'] as num).toDouble();
        final expense = (row['total_expense'] as num).toDouble();
        final balance = account.openingBalance + income - expense;
        totalIncome += income;
        totalExpense += expense;
        totalBalance += balance;
        details.add({
          'account': account,
          'openingBalance': account.openingBalance,
          'income': income,
          'expense': expense,
          'balance': balance,
        });
      }
      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'totalBalance': totalBalance,
        'accounts': accounts,
        'accountDetails': details,
        'unassignedExpense': unassigned,
        'unassignedExpenseCount': legacy.single['count'],
        'recentTransactions': recent,
      };
    });
  }

  Future<List<Map<String, dynamic>>> getAccountDetails() async =>
      (await getAnalysisData())['accountDetails'] as List<Map<String, dynamic>>;
}
