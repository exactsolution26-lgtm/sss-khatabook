import '../db_helper.dart';
import '../../features/entries/party_snapshot.dart';
import '../../features/entries/attachments.dart';
import '../../models/expense_model.dart';

class ExpenseTable {
  static Future<int> insertExpense(ExpenseModel expense, {List<PendingAttachment> attachments = const []}) async {
    if (expense.accountId == null || expense.accountId! <= 0) {
      throw ArgumentError('Select an account for this expense');
    }
    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('Expense amount must be positive and finite');
    }
    final db = await DBHelper.database;
    final snapshot = PartySnapshot.optional(expense.contactName, expense.contactPhone);
    final values = expense.toMap()
      ..remove('id')
      ..['created_at'] = DateTime.now().toUtc().toIso8601String()
      ..['updated_at'] = null;
    values.addAll(snapshot?.toMap() ?? {'contact_name': null, 'contact_phone': null});
    return db.transaction((txn) async {
      final id = await txn.insert('expenses', values);
      await AttachmentStore.insertBatch(txn, attachments, expenseId: id);
      return id;
    });
  }
}
