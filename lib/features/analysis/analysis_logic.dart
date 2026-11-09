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
        SELECT * FROM (SELECT e.id, e.account_id, e.amount, e.description AS note,
          e.date, e.created_at, e.contact_name, e.contact_phone, e.category, e.mode,
          a.name AS account_name, 'income' AS kind
        FROM income e LEFT JOIN accounts a ON a.id=e.account_id
        UNION ALL
        SELECT e.id, e.account_id, e.amount, e.note,
          e.date, e.created_at, e.contact_name, e.contact_phone, e.category, e.mode,
          a.name AS account_name, 'expense' AS kind
        FROM expenses e LEFT JOIN accounts a ON a.id=e.account_id)
        ORDER BY date DESC, datetime(created_at) DESC, kind ASC, id DESC LIMIT 12
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


  /// Stable keyset paging for the combined financial history.
  /// The cursor uses (date, kind, id), avoiding OFFSET skips on large ledgers.
  /// This is a data API; UI pagination and running-balance display are separate.
  Future<List<Map<String, Object?>>> getHistoryPage({
    int? accountId,
    String? kind,
    String? fromDate,
    String? toDate,
    String? beforeDate,
    String? beforeKind,
    int? beforeId,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError('Invalid page size');
    if (kind != null && kind != 'income' && kind != 'expense') {
      throw ArgumentError('Invalid entry type');
    }
    bool validDate(String? value) =>
        value == null || (RegExp(r'^\\d{4}-\\d{2}-\\d{2}$').hasMatch(value) &&
        DateTime.tryParse(value) != null &&
        DateTime.parse(value).toIso8601String().startsWith(value));
    if (!validDate(fromDate) || !validDate(toDate) || !validDate(beforeDate) ||
        (fromDate != null && toDate != null && fromDate.compareTo(toDate) > 0)) {
      throw ArgumentError('Invalid date range');
    }
    if ((beforeDate == null) != (beforeKind == null) ||
        (beforeDate == null) != (beforeId == null) ||
        (beforeKind != null && beforeKind != 'income' && beforeKind != 'expense') ||
        (beforeId != null && beforeId < 1)) {
      throw ArgumentError('Invalid history cursor');
    }
    final where = <String>[];
    final args = <Object?>[];
    if (accountId != null) {
      if (accountId < 1) throw ArgumentError('Invalid account');
      where.add('account_id=?');
      args.add(accountId);
    }
    if (kind != null) { where.add('kind=?'); args.add(kind); }
    if (fromDate != null) { where.add('date>=?'); args.add(fromDate); }
    if (toDate != null) { where.add('date<=?'); args.add(toDate); }
    if (beforeDate != null) {
      where.add('(date < ? OR (date = ? AND kind > ?) OR (date = ? AND kind = ? AND id < ?))');
      args.addAll([beforeDate, beforeDate, beforeKind, beforeDate, beforeKind, beforeId]);
    }
    final filter = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final db = await DBHelper.database;
    return db.rawQuery('''
      SELECT id,account_id,amount,date,created_at,note,category,mode,kind
      FROM (
        SELECT id,account_id,amount,date,created_at,description AS note,
               category,mode,'income' AS kind FROM income
        UNION ALL
        SELECT id,account_id,amount,date,created_at,note,
               category,mode,'expense' AS kind FROM expenses
      )
      $filter
      ORDER BY date DESC,kind ASC,id DESC
      LIMIT ?
    ''', [...args, limit]);
  }

  Future<List<Map<String, dynamic>>> getAccountDetails() async =>
      (await getAnalysisData())['accountDetails'] as List<Map<String, dynamic>>;
}
