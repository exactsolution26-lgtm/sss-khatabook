import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../core/utils/money.dart';
import '../backup/backup_service.dart';
import '../entries/party_snapshot.dart';

class DuesService {
  static String operationKey() => BackupCipher.randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Future<int> create({required int accountId, required bool receivable, required int amountPaise,
      required String description, String? dueDate, String? contactName, String? contactPhone}) async {
    if (amountPaise <= 0 || amountPaise > Money.maximumPaise || description.trim().isEmpty || description.length > 2000) {
      throw ArgumentError('Enter a description and positive amount');
    }
    if (dueDate != null && (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dueDate) ||
      DateTime.tryParse(dueDate) == null || dates.DateUtils.formatDate(DateTime.parse(dueDate)) != dueDate)) throw ArgumentError('Invalid due date');
    final contact = PartySnapshot.optional(contactName, contactPhone);
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final id = await txn.insert('obligations', {'account_id': accountId, 'kind': receivable ? 'receivable' : 'payable',
        'total_paise': amountPaise, 'description': description.trim(), 'due_date': dueDate,
        ...?contact?.toMap(), 'created_at': DateTime.now().toUtc().toIso8601String()});
      await txn.insert('app_audit', {'entity': 'obligation', 'record_id': id, 'operation': 'insert',
        'new_amount': amountPaise / 100, 'new_label': description.trim(), 'new_date': dueDate,
        'new_contact_name': contact?.name, 'new_contact_phone': contact?.phone});
      return id;
    });
  }
  Future<List<Map<String, Object?>>> list({int? accountId}) async => (await DBHelper.database).rawQuery('''
    SELECT o.*, a.name AS account_name, COALESCE(p.paid,0) AS paid_paise,
    o.total_paise-COALESCE(p.paid,0) AS remaining_paise FROM obligations o
    JOIN accounts a ON a.id=o.account_id LEFT JOIN
    (SELECT obligation_id,SUM(amount_paise) AS paid FROM payment_allocations WHERE reversed_at IS NULL GROUP BY obligation_id) p ON p.obligation_id=o.id
    ${accountId == null ? '' : 'WHERE o.account_id=?'} ORDER BY o.due_date IS NULL,o.due_date,o.id DESC''', [if (accountId != null) accountId]);
  Future<List<Map<String, Object?>>> payments(int obligationId) async => (await DBHelper.database).query(
    'payment_allocations', where: 'obligation_id=?', whereArgs: [obligationId], orderBy: 'id DESC');

  Future<int> recordPayment({required int obligationId, required int amountPaise, required String operationKey,
      String mode = 'cash', String note = ''}) async {
    if (amountPaise <= 0 || amountPaise > Money.maximumPaise ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(operationKey) || !['cash','bank','upi','card'].contains(mode) || note.length > 2000) {
      throw ArgumentError('Invalid payment');
    }
    return (await DBHelper.database).transaction((txn) async {
      final prior = await txn.query('payment_allocations', where: 'operation_key=?', whereArgs: [operationKey]);
      if (prior.isNotEmpty) {
        final row = prior.single;
        if (row['obligation_id'] != obligationId || row['amount_paise'] != amountPaise || row['mode'] != mode || row['note'] != note) {
          throw StateError('Operation key already belongs to a different payment');
        }
        if (row['reversed_at'] != null) throw StateError('Payment was reversed; start a new request');
        return row['id'] as int;
      }
      final obligations = await txn.query('obligations', where: 'id=?', whereArgs: [obligationId]);
      if (obligations.length != 1) throw StateError('Amount due not found');
      final due = obligations.single;
      final incoming = due['kind'] == 'receivable';
      final entryId = await _cashEntry(txn, due, incoming: incoming, paise: amountPaise, mode: mode,
        note: note.isEmpty ? due['description'] as String : note, category: incoming ? 'Receivable Settlement' : 'Bill Payment');
      final id = await txn.insert('payment_allocations', {'obligation_id': obligationId, 'amount_paise': amountPaise,
        (incoming ? 'income_id' : 'expense_id'): entryId, 'operation_key': operationKey, 'mode': mode, 'note': note,
        'created_at': DateTime.now().toUtc().toIso8601String()});
      await txn.insert('app_audit', {'entity': 'payment_allocation', 'record_id': id, 'operation': 'payment',
        'new_amount': amountPaise / 100, 'new_label': 'Obligation #$obligationId'});
      return id;
    });
  }
  Future<void> reversePayment(int paymentId, String reason) async {
    if (reason.trim().isEmpty || reason.length > 500) throw ArgumentError('Reversal reason required');
    await (await DBHelper.database).transaction((txn) async {
      final payments = await txn.query('payment_allocations', where: 'id=?', whereArgs: [paymentId]);
      if (payments.length != 1 || payments.single['reversed_at'] != null) throw StateError('Payment is unavailable or already reversed');
      final payment = payments.single;
      final due = (await txn.query('obligations', where: 'id=?', whereArgs: [payment['obligation_id']])).single;
      final original = (await txn.query(payment['income_id'] == null ? 'expenses' : 'income',
        where: 'id=?', whereArgs: [payment['income_id'] ?? payment['expense_id']])).single;
      final incoming = due['kind'] == 'payable';
      final id = await _cashEntry(txn, {...due, 'contact_name': original['contact_name'], 'contact_phone': original['contact_phone']}, incoming: incoming, paise: payment['amount_paise'] as int,
        mode: payment['mode'] as String, note: 'Reversal #$paymentId: ${reason.trim()}', category: 'Payment Reversal');
      await txn.update('payment_allocations', {'reversed_at': DateTime.now().toUtc().toIso8601String(),
        'reversal_reason': reason.trim(), (incoming ? 'reversal_income_id' : 'reversal_expense_id'): id},
        where: 'id=?', whereArgs: [paymentId]);
      await txn.insert('app_audit', {'entity': 'payment_allocation', 'record_id': paymentId, 'operation': 'reversal',
        'old_amount': (payment['amount_paise'] as num) / 100, 'new_label': reason.trim()});
    });
  }
  Future<int> _cashEntry(DatabaseExecutor txn, Map<String, Object?> due, {required bool incoming,
      required int paise, required String mode, required String note, required String category}) => txn.insert(incoming ? 'income' : 'expenses', {
    'account_id': due['account_id'], 'amount': paise / 100, 'mode': mode, 'category': category,
    (incoming ? 'description' : 'note'): note, 'contact_name': due['contact_name'], 'contact_phone': due['contact_phone'],
    'date': dates.DateUtils.formatDate(dates.DateUtils.indiaToday()), 'created_at': DateTime.now().toUtc().toIso8601String(),
  });
}
