import '../../core/utils/date_utils.dart';
import '../../database/db_helper.dart';
import '../../models/account_model.dart';

class AnalysisLogic {
  /// One SQLite snapshot keeps totals and account details mutually consistent.
  Future<Map<String, dynamic>> getAnalysisData({
    bool includeDashboardAnalytics = false,
  }) async {
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery('''SELECT a.*,
        COALESCE(i.total,0) AS income_paise, COALESCE(e.total,0) AS expense_paise
        FROM accounts a
        LEFT JOIN (SELECT account_id,TOTAL(ROUND(amount * 100)) AS total FROM income GROUP BY account_id) i ON i.account_id=a.id
        LEFT JOIN (SELECT account_id,TOTAL(ROUND(amount * 100)) AS total FROM expenses GROUP BY account_id) e ON e.account_id=a.id
        ORDER BY a.id''');
      final legacy = await txn.rawQuery(
        'SELECT COUNT(*) AS count,TOTAL(ROUND(amount * 100)) AS total FROM expenses WHERE account_id IS NULL',
      );
      final unassigned = (legacy.single['total'] as num).round();
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
      var totalIncome = 0;
      var totalExpense = unassigned;
      var totalBalance = -unassigned;
      final details = <Map<String, dynamic>>[];
      final accounts = <AccountModel>[];
      for (final row in rows) {
        final account = AccountModel.fromMap(row);
        accounts.add(account);
        final income = (row['income_paise'] as num).round();
        final expense = (row['expense_paise'] as num).round();
        final opening = (account.openingBalance * 100).round();
        final balance = opening + income - expense;
        totalIncome += income;
        totalExpense += expense;
        totalBalance += balance;
        details.add({
          'account': account,
          'openingBalance': opening / 100,
          'income': income / 100,
          'expense': expense / 100,
          'balance': balance / 100,
        });
      }
      final today = DateUtils.indiaToday();
      final first = DateUtils.formatDate(DateTime(today.year, today.month - 1));
      final end = DateUtils.formatDate(DateTime(today.year, today.month + 1));
      final analytics = includeDashboardAnalytics ? await txn.rawQuery('''
        SELECT month, week, kind, category, SUM(paise) AS paise
        FROM (
          SELECT substr(date, 1, 7) AS month,
            (CAST(substr(date, 9, 2) AS INTEGER) - 1) / 7 AS week,
            'income' AS kind, '' AS category, ROUND(amount * 100) AS paise
          FROM income WHERE date >= ? AND date < ?
          UNION ALL
          SELECT substr(date, 1, 7),
            (CAST(substr(date, 9, 2) AS INTEGER) - 1) / 7,
            'expense', COALESCE(NULLIF(TRIM(category), ''), ''), ROUND(amount * 100)
          FROM expenses WHERE date >= ? AND date < ?
        )
        WHERE week BETWEEN 0 AND 4
        GROUP BY month, week, kind, category
      ''', [first, end, first, end]) : const <Map<String, Object?>>[];
      return {
        'totalIncome': totalIncome / 100,
        'totalExpense': totalExpense / 100,
        'totalBalance': totalBalance / 100,
        'accounts': accounts,
        'accountDetails': details,
        'unassignedExpense': unassigned / 100,
        'unassignedExpenseCount': legacy.single['count'],
        'recentTransactions': recent,
        'dashboardAnalytics': analytics,
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
        value == null || (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
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
