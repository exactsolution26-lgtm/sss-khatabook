import '../db_helper.dart';
import '../../models/expense_model.dart';
import '../../core/utils/money.dart';

class ExpenseTable {
  static Future<void> insertExpense(ExpenseModel expense) async {
    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('Invalid amount');
    }
    if (expense.category.trim().isEmpty) {
      throw ArgumentError('Category required');
    }
    if (expense.mode != 'cash' && expense.mode != 'online') {
      throw ArgumentError('Invalid mode');
    }
    final amount = Money.parseRupees(expense.amount.toStringAsFixed(2)).paise;
    final account = expense.mode == 'cash' ? 'local-cash' : 'local-bank';
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await DBHelper.database;
    await db.transaction((tx) async {
      await tx.insert('transactions', {
        'id': 'expense-${DateTime.now().microsecondsSinceEpoch}',
        'business_id': 'local-demo',
        'account_id': account,
        'type': 'expense',
        'amount_paise': amount,
        'category': expense.category.trim(),
        'payment_mode': expense.mode == 'cash' ? 'cash' : 'bank',
        'note': expense.note,
        'occurred_at_utc': DateTime.parse(expense.date).toUtc().toIso8601String(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      final changed = await tx.rawUpdate(
        'UPDATE accounts SET balance_paise = balance_paise - ? WHERE id = ? AND business_id = ?',
        [amount, account, 'local-demo'],
      );
      if (changed != 1) throw StateError('Expense account not found');
    });
  }
}
